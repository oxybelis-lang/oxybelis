import * as vscode from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient/node';
import { execFileSync } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

let client: LanguageClient;
let outputChannel: vscode.OutputChannel;
let diagCollection: vscode.DiagnosticCollection;

function log(msg: string) {
  if (outputChannel) outputChannel.appendLine(msg);
}

function findExe(name: string, extPath: string, settingPath?: string): string | null {
  if (settingPath) {
    const val = vscode.workspace.getConfiguration('oxybelis').get<string>(settingPath, '');
    if (val && fs.existsSync(val)) return val;
  }
  const local = path.join(extPath, '..', '..', 'dist', 'release', name + '.exe');
  if (fs.existsSync(local)) return local;
  const localPy = path.join(extPath, '..', '..', 'src', name + '.py');
  if (fs.existsSync(localPy)) return localPy;
  const binDir = path.join(process.env.LOCALAPPDATA || process.env.HOME || '', 'oxybelis', 'bin');
  for (const ext of ['.exe', '.bat', '']) {
    const full = path.join(binDir, name + ext);
    if (fs.existsSync(full)) return full;
  }
  try {
    const r = execFileSync('where.exe', [name], { encoding: 'utf-8', timeout: 5000 });
    for (const line of r.trim().split(/\r?\n/)) {
      if (fs.existsSync(line)) return line;
    }
  } catch { /* ignore */ }
  return null;
}

export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel('Oxybelis');
  outputChannel.show(true);
  log('=== Oxybelis extension activating ===');

  const oxybelisBin = findExe('oxybelis', context.extensionPath, 'compiler.oxybelisPath');
  const oxfmtBin = findExe('ox-fmt', context.extensionPath, 'formatter.serverPath');
  const oxlspBin = findExe('ox-lsp', context.extensionPath, 'lsp.serverPath');
  log(`oxybelis: ${oxybelisBin || 'NOT FOUND'}`);
  log(`ox-fmt:   ${oxfmtBin || 'NOT FOUND'}`);
  log(`ox-lsp:   ${oxlspBin || 'NOT FOUND'}`);

  diagCollection = vscode.languages.createDiagnosticCollection('oxybelis');
  context.subscriptions.push(diagCollection);

  // ── Diagnostics on save (via ox-lsp check) ──
  if (oxlspBin) {
    context.subscriptions.push(
      vscode.workspace.onDidSaveTextDocument(async (doc) => {
        if (doc.languageId !== 'oxybelis') return;
        runCheck(doc.uri.fsPath, oxlspBin);
      })
    );
  }

  // ── Formatter (no deps) ──────────────────────────────
  if (oxfmtBin) {
    log(`Formatter: ${oxfmtBin}`);
    context.subscriptions.push(
      vscode.languages.registerDocumentFormattingEditProvider('oxybelis', {
        async provideDocumentFormattingEdits(doc: vscode.TextDocument): Promise<vscode.TextEdit[]> {
          try {
            const formatted = execFileSync(oxfmtBin, [doc.fileName, '--stdout'], { encoding: 'utf-8', timeout: 15000 });
            const range = doc.validateRange(new vscode.Range(0, 0, doc.lineCount, 0));
            return [vscode.TextEdit.replace(range, formatted)];
          } catch (e: any) {
            log(`Format error: ${e.message}`);
            vscode.window.showErrorMessage(`Format failed: ${e.message}`);
            return [];
          }
        },
      })
    );
  }

  // ── Commands (no deps) ──────────────────────────────
  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.check', () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed || !oxlspBin) return;
      runCheck(ed.document.fileName, oxlspBin);
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.transpile', () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed || !oxybelisBin) return;
      const outFile = ed.document.fileName.replace(/\.ox$/, '.cpp');
      try {
        execFileSync(oxybelisBin, [ed.document.fileName, '-o', outFile], { encoding: 'utf-8', timeout: 30000 });
        vscode.window.showInformationMessage(`Transpiled to ${outFile}`);
      } catch (e: any) { vscode.window.showErrorMessage(`Transpile failed: ${e.message}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.highlight', () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed || !oxybelisBin) return;
      try {
        const out = execFileSync(oxybelisBin, [ed.document.fileName, '--highlight'], { encoding: 'utf-8', timeout: 30000 });
        outputChannel.appendLine(out);
      } catch (e: any) { log(`Highlight failed: ${e.message}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.build', () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed || !oxybelisBin) return;
      const base = path.basename(ed.document.fileName, '.ox');
      try {
        execFileSync(oxybelisBin, [ed.document.fileName, '-o', base + '.cpp'], { encoding: 'utf-8', timeout: 30000 });
        execFileSync('g++', ['-O3', '-std=c++20', base + '.cpp', '-o', base + '.exe', '-lm'], { stdio: 'inherit', timeout: 60000 });
        vscode.window.showInformationMessage(`Build: ${base}.exe`);
      } catch (e: any) { vscode.window.showErrorMessage(`Build failed: ${e.message}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.format', async () => {
      await vscode.commands.executeCommand('editor.action.formatDocument');
    })
  );

  log('=== Activation complete ===');

  // ── LSP (start last, don't block activation) ─────────
  if (oxlspBin) {
    log(`Starting LSP: ${oxlspBin}`);
    const serverOptions: ServerOptions = {
      command: oxlspBin,
      transport: TransportKind.stdio,
    };
    const clientOptions: LanguageClientOptions = {
      documentSelector: [{ scheme: 'file', language: 'oxybelis' }],
      outputChannel,

    };
    client = new LanguageClient('oxybelis', 'Oxybelis Language Server', serverOptions, clientOptions);
    client.onDidChangeState((e) => {
      log(`LSP state: ${e.oldState} → ${e.newState}`);
    });
    client.start().then(() => {
      log('LSP started — diagnostics will appear in Problems panel');
    }).catch((e: any) => {
      log(`LSP start failed: ${e.message}`);
    });
  } else {
    log('ox-lsp not found — diagnostics on save will be used');
  }
}

function runCheck(fileName: string, lspBin: string) {
  const uri = vscode.Uri.file(fileName);
  diagCollection.set(uri, undefined);
  try {
    const out = execFileSync(lspBin, ['check', fileName], { encoding: 'utf-8', timeout: 30000 });
    if (out.includes('no errors')) {
      log(`Check passed: ${fileName}`);
    }
  } catch (e: any) {
    const raw = e.stderr || e.stdout || e.message;
    log(`Check errors:\n${stripAnsi(raw)}`);
    const diags = parseDiagnostics(raw);
    diagCollection.set(uri, diags);
  }
}

function stripAnsi(s: string): string {
  return s.replace(/\x1b\[[0-9;]*m/g, '');
}

function parseDiagnostics(text: string): vscode.Diagnostic[] {
  const diags: vscode.Diagnostic[] = [];
  const clean = stripAnsi(text);
  const errRe = /\berror\[(E\d+)\]:\s*(.+)/g;
  const warnRe = /\bwarning\[(W\d+)\]:\s*(.+)/g;
  const locRe = /-->\s*\S+:(\d+):(\d+)/;

  let lines = clean.split('\n');
  let i = 0;
  while (i < lines.length) {
    let m: RegExpExecArray | null;
    let isWarning = false;
    const errMatch = errRe.exec(lines[i]);
    const warnMatch = warnRe.exec(lines[i]);
    let code = '', msg = '';
    if (errMatch) { code = errMatch[1]; msg = errMatch[2]; }
    else if (warnMatch) { code = warnMatch[1]; msg = warnMatch[2]; isWarning = true; }
    else { i++; continue; }

    let line = 0, col = 0;
    for (let j = i + 1; j < Math.min(i + 4, lines.length); j++) {
      const loc = lines[j].match(locRe);
      if (loc) { line = parseInt(loc[1]) - 1; col = parseInt(loc[2]) - 1; break; }
    }

    const sev = isWarning ? vscode.DiagnosticSeverity.Warning : vscode.DiagnosticSeverity.Error;
    const range = new vscode.Range(line, col, line, col + 20);
    const diag = new vscode.Diagnostic(range, `[${code}] ${msg}`, sev);
    diag.source = 'oxybelis';
    diags.push(diag);
    i++;
  }
  return diags;
}

export function deactivate(): Thenable<void> | undefined {
  if (client) return client.stop();
}
