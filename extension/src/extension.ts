import * as vscode from 'vscode';
import { execFileSync } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

let outputChannel: vscode.OutputChannel;

function log(msg: string) {
  if (outputChannel) outputChannel.appendLine(msg);
}

function findOnPath(name: string): string | null {
  try {
    const r = execFileSync('where.exe', [name], { encoding: 'utf-8', timeout: 5000 });
    for (const line of r.trim().split(/\r?\n/)) {
      const ext = path.extname(line).toLowerCase();
      if (ext === '.exe' && fs.existsSync(line)) return line;
    }
    return null;
  } catch { return null; }
}

function findExe(name: string, extPath: string): string | null {
  const local = path.join(extPath, '..', '..', 'dist', 'release', name + '.exe');
  if (fs.existsSync(local)) return local;
  const installed = path.join(process.env.LOCALAPPDATA || '', 'oxybelis', 'bin', name + '.exe');
  if (fs.existsSync(installed)) return installed;
  const onPath = findOnPath(name);
  if (onPath) return onPath;
  return null;
}

export async function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel('Oxybelis');
  outputChannel.show(true);
  log('=== Oxybelis extension activating ===');
  log(`extPath: ${context.extensionPath}`);

  // Register ONE test command first to confirm activation works
  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.hello', () => {
      vscode.window.showInformationMessage('Oxybelis extension is alive!');
    })
  );

  // Find binaries
  const oxybelisBin = findExe('oxybelis', context.extensionPath);
  const oxfmtBin = findExe('ox-fmt', context.extensionPath);
  const oxlspBin = findExe('ox-lsp', context.extensionPath);
  log(`oxybelis: ${oxybelisBin || 'NOT FOUND'}`);
  log(`ox-fmt:   ${oxfmtBin || 'NOT FOUND'}`);
  log(`ox-lsp:   ${oxlspBin || 'NOT FOUND'}`);

  // Register commands
  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.check', async () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed) return;
      log(`check: ${ed.document.fileName}`);
      if (!oxybelisBin) { vscode.window.showErrorMessage('oxybelis binary not found'); return; }
      try {
        const out = execFileSync(oxybelisBin, [ed.document.fileName, '--check'], { encoding: 'utf-8', timeout: 30000 });
        log(`check OK:\n${out}`);
        vscode.window.showInformationMessage('Type check passed');
      } catch (e: any) {
        log(`check FAILED: ${e.message}`);
        vscode.window.showErrorMessage(`Check failed: ${e.message}`);
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.highlight', async () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed) return;
      if (!oxybelisBin) return;
      try {
        const out = execFileSync(oxybelisBin, [ed.document.fileName, '--highlight'], { encoding: 'utf-8', timeout: 30000 });
        log(`highlight:\n${out}`);
      } catch (e: any) { log(`highlight failed: ${e.message}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.transpile', async () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed) return;
      if (!oxybelisBin) return;
      const outFile = ed.document.fileName.replace(/\.ox$/, '.cpp');
      try {
        execFileSync(oxybelisBin, [ed.document.fileName, '-o', outFile], { encoding: 'utf-8', timeout: 30000 });
        vscode.window.showInformationMessage(`Transpiled to ${outFile}`);
      } catch (e: any) { vscode.window.showErrorMessage(`Transpile failed: ${e.message}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.build', async () => {
      const ed = vscode.window.activeTextEditor;
      if (!ed) return;
      if (!oxybelisBin) return;
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

  // Register formatter
  if (oxfmtBin) {
    log(`Registering formatter: ${oxfmtBin}`);
    context.subscriptions.push(
      vscode.languages.registerDocumentFormattingEditProvider('oxybelis', {
        async provideDocumentFormattingEdits(doc: vscode.TextDocument): Promise<vscode.TextEdit[]> {
          log(`Formatting: ${doc.fileName}`);
          try {
            const formatted = execFileSync(oxfmtBin, [doc.fileName], { encoding: 'utf-8', timeout: 15000 });
            const range = doc.validateRange(new vscode.Range(0, 0, doc.lineCount, 0));
            log('Format OK');
            return [vscode.TextEdit.replace(range, formatted)];
          } catch (e: any) {
            log(`Format error: ${e.message}`);
            vscode.window.showErrorMessage(`Format failed: ${e.message}`);
            return [];
          }
        },
      })
    );
  } else {
    log('ox-fmt not found, formatter not registered');
  }

  // Start LSP
  if (oxlspBin) {
    log(`Starting LSP: ${oxlspBin}`);
    try {
      const lsp = execFileSync(oxlspBin, ['--help'], { encoding: 'utf-8', timeout: 5000 });
      log(`LSP binary responds: ${lsp.trim().split('\n')[0]}`);
    } catch {
      log('LSP binary check failed');
    }
  } else {
    log('ox-lsp not found, LSP not started');
  }

  log('=== Activation complete ===');
}

export function deactivate() {}
