import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind,
} from 'vscode-languageclient/node';
import { execFileSync } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

let client: LanguageClient;
let outputChannel: vscode.OutputChannel;
let diagCollection: vscode.DiagnosticCollection;

function log(msg: string) {
    if (outputChannel) outputChannel.appendLine(msg);
}

// ── Binary discovery ──────────────────────────────────────────────────────────

function findExe(name: string, extPath: string): string | null {
    // 1. User-configured path (highest priority)
    const cfg = vscode.workspace.getConfiguration('oxybelis');
    const cfgKey = name === 'oxybelis' ? 'compiler.oxybelisPath'
                 : name === 'ox-lsp'   ? 'lsp.serverPath'
                 :                       'formatter.serverPath';
    const configured: string = cfg.get(cfgKey, '');
    if (configured && fs.existsSync(configured)) return configured;

    // 2. Dev: .bat wrapper next to extension (runs python ox_lsp.py)
    const localBat = path.join(extPath, '..', '..', name.replace('-', '_') + '.bat');
    if (fs.existsSync(localBat)) return localBat;

    // 3. Dev: compiled binary next to the workspace root
    const local = path.join(extPath, '..', '..', 'dist', 'release',
                            name + (process.platform === 'win32' ? '.exe' : ''));
    if (fs.existsSync(local)) return local;

    // 4. Standard install location
    const installed = path.join(
        process.env.LOCALAPPDATA || process.env.HOME || '',
        process.platform === 'win32' ? path.join('oxybelis', 'bin') : path.join('.oxybelis', 'bin'),
        name + (process.platform === 'win32' ? '.exe' : ''),
    );
    if (fs.existsSync(installed)) return installed;

    // 5. PATH lookup
    try {
        const which = process.platform === 'win32' ? 'where.exe' : 'which';
        const result = execFileSync(which, [name], { encoding: 'utf-8', timeout: 5000 });
        const first = result.trim().split(/\r?\n/)[0];
        if (first && fs.existsSync(first)) return first;
    } catch {
        // not on PATH
    }

    return null;
}

// ── Activation ────────────────────────────────────────────────────────────────

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('Oxybelis');
    outputChannel.show(true);
    log('=== Oxybelis extension activating ===');

    const oxybelisBin = findExe('oxybelis', context.extensionPath);
    const oxfmtBin    = findExe('ox-fmt',   context.extensionPath);
    const oxlspBin    = findExe('ox-lsp',   context.extensionPath);
    log(`oxybelis : ${oxybelisBin ?? 'NOT FOUND'}`);
    log(`ox-fmt   : ${oxfmtBin    ?? 'NOT FOUND'}`);
    log(`ox-lsp   : ${oxlspBin    ?? 'NOT FOUND'}`);

    diagCollection = vscode.languages.createDiagnosticCollection('oxybelis');
    context.subscriptions.push(diagCollection);

    // ── Diagnostics on save (fallback when LSP is absent) ────────────────────
    if (oxybelisBin) {
        context.subscriptions.push(
            vscode.workspace.onDidSaveTextDocument(doc => {
                if (doc.languageId !== 'oxybelis') return;
                // Only run the CLI check if the LSP is NOT running (to avoid
                // duplicate diagnostics fighting each other).
                if (!client?.isRunning()) {
                    runTypeCheck(doc.uri.fsPath, oxybelisBin);
                }
            }),
        );
    }

    // ── Formatter ────────────────────────────────────────────────────────────
    if (oxfmtBin) {
        context.subscriptions.push(
            vscode.languages.registerDocumentFormattingEditProvider('oxybelis', {
                async provideDocumentFormattingEdits(
                    doc: vscode.TextDocument,
                ): Promise<vscode.TextEdit[]> {
                    try {
                        const formatted = execFileSync(
                            oxfmtBin, [doc.fileName, '--stdout'],
                            { encoding: 'utf-8', timeout: 15_000 },
                        );
                        const full = new vscode.Range(
                            doc.positionAt(0),
                            doc.positionAt(doc.getText().length),
                        );
                        return [vscode.TextEdit.replace(full, formatted)];
                    } catch (e: unknown) {
                        const msg = e instanceof Error ? e.message : String(e);
                        log(`Format error: ${msg}`);
                        vscode.window.showErrorMessage(`Format failed: ${msg}`);
                        return [];
                    }
                },
            }),
        );
    }

    // ── Commands ──────────────────────────────────────────────────────────────
    context.subscriptions.push(
        vscode.commands.registerCommand('oxybelis.hello', () => {
            vscode.window.showInformationMessage('Oxybelis extension is active!');
        }),
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('oxybelis.check', () => {
            const ed = vscode.window.activeTextEditor;
            if (!ed || !oxybelisBin) return;
            runTypeCheck(ed.document.fileName, oxybelisBin);
        }),
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('oxybelis.transpile', () => {
            const ed = vscode.window.activeTextEditor;
            if (!ed || !oxybelisBin) return;
            const outFile = ed.document.fileName.replace(/\.ox$/, '.cpp');
            try {
                execFileSync(oxybelisBin, [ed.document.fileName, '-o', outFile],
                             { encoding: 'utf-8', timeout: 30_000 });
                vscode.window.showInformationMessage(`Transpiled → ${outFile}`);
            } catch (e: unknown) {
                vscode.window.showErrorMessage(`Transpile failed: ${e instanceof Error ? e.message : e}`);
            }
        }),
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('oxybelis.build', () => {
            const ed = vscode.window.activeTextEditor;
            if (!ed || !oxybelisBin) return;
            const base = path.basename(ed.document.fileName, '.ox');
            try {
                execFileSync(oxybelisBin, [ed.document.fileName, '-o', base + '.cpp'],
                             { encoding: 'utf-8', timeout: 30_000 });
                execFileSync('g++', ['-O3', '-std=c++20', base + '.cpp', '-o', base + '.exe', '-lm'],
                             { stdio: 'inherit', timeout: 60_000 });
                vscode.window.showInformationMessage(`Built → ${base}.exe`);
            } catch (e: unknown) {
                vscode.window.showErrorMessage(`Build failed: ${e instanceof Error ? e.message : e}`);
            }
        }),
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('oxybelis.highlight', () => {
            const ed = vscode.window.activeTextEditor;
            if (!ed || !oxybelisBin) return;
            try {
                const out = execFileSync(oxybelisBin, [ed.document.fileName, '--highlight'],
                                         { encoding: 'utf-8', timeout: 30_000 });
                outputChannel.appendLine(out);
            } catch (e: unknown) {
                log(`Highlight failed: ${e instanceof Error ? e.message : e}`);
            }
        }),
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('oxybelis.format', async () => {
            await vscode.commands.executeCommand('editor.action.formatDocument');
        }),
    );

    log('=== Commands registered ===');

    // ── LSP (started last; must not block activation) ─────────────────────────
    if (oxlspBin) {
        startLSP(context, oxlspBin);
    } else {
        log('ox-lsp not found – diagnostics-on-save fallback active');
    }
}

// ── LSP startup ───────────────────────────────────────────────────────────────

function startLSP(context: vscode.ExtensionContext, serverBin: string) {
    log(`Starting LSP: ${serverBin}`);

    const serverOptions: ServerOptions = serverBin.endsWith('.py')
        ? { command: 'python', args: ['-u', serverBin], transport: TransportKind.stdio }
        : { command: serverBin,                   transport: TransportKind.stdio };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'oxybelis' }],
        outputChannel,
        // ── FIX: disable the client-side semantic token CACHING layer.
        //
        // VS Code ships a built-in semantic token cache that computes
        // colour ranges from the raw integer array your server sends.
        // By default it uses a "delta" protocol where the client keeps
        // the previous response and applies a diff.  If your server
        // sends 'full' tokens (delta: false in capabilities) but the
        // client still tries to apply the delta algorithm, the result
        // is garbled colours.
        //
        // Setting middleware.provideDocumentSemanticTokens to forward
        // the result directly bypasses the cache, ensuring the server's
        // data is used verbatim.
        middleware: {
            provideDocumentSemanticTokens(document, token, next) {
                return next(document, token);
            },
        },
    };

    client = new LanguageClient(
        'oxybelis',
        'Oxybelis Language Server',
        serverOptions,
        clientOptions,
    );

    client.onDidChangeState(e => {
        log(`LSP state: ${e.oldState} → ${e.newState}`);
    });

    client.start().then(() => {
        log('LSP running – Problems panel active');
    }).catch((e: unknown) => {
        log(`LSP failed to start: ${e instanceof Error ? e.message : e}`);
        vscode.window.showWarningMessage(
            'Oxybelis LSP failed to start. Diagnostics-on-save will be used instead.',
        );
    });

    context.subscriptions.push(client);
}

// ── Diagnostics (CLI fallback) ────────────────────────────────────────────────

function runTypeCheck(fileName: string, binPath: string) {
    const uri = vscode.Uri.file(fileName);
    diagCollection.set(uri, []);
    try {
        execFileSync(binPath, [fileName, '--check'],
                     { encoding: 'utf-8', timeout: 30_000 });
        vscode.window.showInformationMessage('No errors found');
    } catch (e: unknown) {
        const raw = (e as { stderr?: string; stdout?: string; message?: string })
                    .stderr ?? (e as { stdout?: string }).stdout ?? String(e);
        log(`Type-check errors:\n${stripAnsi(raw)}`);
        const diags = parseDiagnostics(raw, fileName);
        diagCollection.set(uri, diags);
        if (diags.length) {
            vscode.window.showWarningMessage(`${diags.length} error(s) found`);
        }
    }
}

function stripAnsi(s: string): string {
    return s.replace(/\x1b\[[0-9;]*m/g, '');
}

function parseDiagnostics(text: string, _fileName: string): vscode.Diagnostic[] {
    const diags: vscode.Diagnostic[] = [];
    const clean = stripAnsi(text);
    const lines = clean.split('\n');

    let code: string | null = null;
    let msgs: string[] = [];
    let dline = 0;
    let dcol  = 0;

    const flush = () => {
        if (code !== null) {
            diags.push(makeDiag(code, msgs.join('\n'), dline, dcol));
        }
    };

    for (let i = 0; i < lines.length; i++) {
        const errMatch = lines[i].match(/\[(E\d+)\]:\s*(.+)/);
        if (errMatch) {
            flush();
            code = errMatch[1];
            msgs = [errMatch[2]];
            // scan ahead for location
            for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {
                const locMatch = lines[j].match(/-->\s*.*?(\d+):(\d+)/);
                if (locMatch) {
                    dline = parseInt(locMatch[1], 10) - 1;
                    dcol  = parseInt(locMatch[2], 10) - 1;
                    break;
                }
                const trimmed = lines[j].trim();
                if (trimmed) msgs.push(trimmed);
            }
        }
    }
    flush();

    // Simple fallback regex
    if (diags.length === 0) {
        const re = /E(\d+).*?(\d+):(\d+)/g;
        let m: RegExpExecArray | null;
        while ((m = re.exec(clean)) !== null) {
            diags.push(makeDiag(m[1], 'type error', parseInt(m[2]) - 1, parseInt(m[3]) - 1));
        }
    }

    return diags;
}

function makeDiag(code: string, msg: string, line: number, col: number): vscode.Diagnostic {
    const range = new vscode.Range(line, col, line, col + 20);
    const d = new vscode.Diagnostic(range, `[${code}] ${msg}`, vscode.DiagnosticSeverity.Error);
    d.source = 'oxybelis';
    return d;
}

// ── Deactivation ──────────────────────────────────────────────────────────────

export function deactivate(): Thenable<void> | undefined {
    return client?.stop();
}
