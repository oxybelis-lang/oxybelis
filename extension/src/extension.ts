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

function findExe(name: string, extPath: string): string | null {
  const local = path.join(extPath, '..', '..', 'dist', 'release', name + '.exe');
  if (fs.existsSync(local)) return local;
  const installed = path.join(process.env.LOCALAPPDATA || '', 'oxybelis', 'bin', name + '.exe');
  if (fs.existsSync(installed)) return installed;
  try {
    const r = execFileSync('where.exe', [name], { encoding: 'utf-8', timeout: 5000 });
    for (const line of r.trim().split(/\r?\n/)) {
      const ext = path.extname(line).toLowerCase();
      if (ext === '.exe' && fs.existsSync(line)) return line;
    }
  } catch { /* ignore */ }
  return null;
}

export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel('Oxybelis');
  outputChannel.show(true);
  log('=== Oxybelis extension activating ===');

  const oxybelisBin = findExe('oxybelis', context.extensionPath);
  const oxfmtBin = findExe('ox-fmt', context.extensionPath);
  const oxlspBin = findExe('ox-lsp', context.extensionPath);
  log(`oxybelis: ${oxybelisBin || 'NOT FOUND'}`);
  log(`ox-fmt:   ${oxfmtBin || 'NOT FOUND'}`);
  log(`ox-lsp:   ${oxlspBin || 'NOT FOUND'}`);

  diagCollection = vscode.languages.createDiagnosticCollection('oxybelis');
  context.subscriptions.push(diagCollection);

  // ── Diagnostics on save (always registered as fallback) ──
  if (oxybelisBin) {
    context.subscriptions.push(
      vscode.workspace.onDidSaveTextDocument(async (doc) => {
        if (doc.languageId !== 'oxybelis') return;
        runTypeCheck(doc.uri.fsPath, oxybelisBin);
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
      if (!ed || !oxybelisBin) return;
      runTypeCheck(ed.document.fileName, oxybelisBin);
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

function runTypeCheck(fileName: string, binPath: string) {
  const uri = vscode.Uri.file(fileName);
  diagCollection.set(uri, undefined); // clear previous
  try {
    const out = execFileSync(binPath, ['check', fileName], { encoding: 'utf-8', timeout: 30000 });
    log(`Check passed: ${fileName}`);
    vscode.window.showInformationMessage('No errors found');
  } catch (e: any) {
    const raw = e.stderr || e.stdout || e.message;
    log(`Check errors:\n${stripAnsi(raw)}`);
    const diags = parseDiagnostics(raw, fileName);
    diagCollection.set(uri, diags);
    vscode.window.showWarningMessage(`${diags.length} error(s) found`);
  }
}

function stripAnsi(s: string): string {
  return s.replace(/\x1b\[[0-9;]*m/g, '');
}

function parseDiagnostics(text: string, fileName: string): vscode.Diagnostic[] {
  const diags: vscode.Diagnostic[] = [];
  const clean = stripAnsi(text);
  const lines = clean.split('\n');

  let currentError: string | null = null;
  let currentMsg: string[] = [];
  let currentLine = 0;
  let currentCol = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    const errMatch = line.match(/\[(E\d+)\]:\s*(.+)/);
    if (errMatch) {
      if (currentError) {
        diags.push(makeDiag(currentError, currentMsg.join('\n'), currentLine, currentCol));
      }
      currentError = errMatch[1];
      currentMsg = [errMatch[2]];

      for (let j = i + 1; j < Math.min(i + 5, lines.length); j++) {
        const locMatch = lines[j].match(/-->.*?(\d+):(\d+)/);
        if (locMatch) {
          currentLine = parseInt(locMatch[1]) - 1;
          currentCol = parseInt(locMatch[2]) - 1;
          break;
        }
        const trimmed = lines[j].trim();
        if (trimmed) currentMsg.push(trimmed);
      }
      i += 4;
    }
  }
  if (currentError) {
    diags.push(makeDiag(currentError, currentMsg.join('\n'), currentLine, currentCol));
  }

  if (diags.length === 0) {
    const simpleRegex = /E(\d+).*?(\d+):(\d+)/g;
    let m;
    while ((m = simpleRegex.exec(clean)) !== null) {
      diags.push(makeDiag(m[1], 'type error', parseInt(m[2]) - 1, parseInt(m[3]) - 1));
    }
  }

  return diags;
}

function makeDiag(code: string, msg: string, line: number, col: number): vscode.Diagnostic {
  const range = new vscode.Range(line, col, line, col + 20);
  const diag = new vscode.Diagnostic(range, `[${code}] ${msg}`, vscode.DiagnosticSeverity.Error);
  diag.source = 'oxybelis';
  return diag;
}

export function deactivate(): Thenable<void> | undefined {
  if (client) return client.stop();
}
