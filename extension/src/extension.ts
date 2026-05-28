import * as vscode from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient/node';
import * as path from 'path';
import * as fs from 'fs';
import { execFileSync } from 'child_process';

let client: LanguageClient;
const outputChannel = vscode.window.createOutputChannel('Oxybelis');

function findBinary(name: string): string | null {
  const candidates = [
    path.join(__dirname, '..', '..', 'dist', 'release', name + '.exe'),
    path.join(__dirname, '..', '..', 'dist', 'release', name),
    path.join(process.env.LOCALAPPDATA || '', 'oxybelis', 'bin', name + '.exe'),
    path.join(process.env.HOME || process.env.USERPROFILE || '', '.oxybelis', 'bin', name),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

function findScript(name: string): string | null {
  const p = path.join(__dirname, '..', '..', name + '.py');
  return fs.existsSync(p) ? p : null;
}

function resolveCommand(config: vscode.WorkspaceConfiguration, name: string, settingKey: string): { command: string; args: string[] } {
  const userPath = config.get<string>(settingKey, '');
  if (userPath) {
    return { command: userPath, args: [] };
  }

  const binary = findBinary(name);
  if (binary) return { command: binary, args: [] };

  const script = findScript(name);
  if (script) return { command: 'python', args: [script] };

  return { command: name, args: [] };
}

function runTool(cmd: string, args: string[], input?: string): string {
  return execFileSync(cmd, args, {
    encoding: 'utf-8',
    stdio: input ? ['pipe', 'pipe', 'pipe'] : ['inherit', 'pipe', 'pipe'],
    input,
    timeout: 30000,
  });
}

export async function activate(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('oxybelis');

  outputChannel.appendLine(`Extension path: ${context.extensionPath}`);
  outputChannel.appendLine(`Activating Oxybelis extension...`);

  // ── LSP ───────────────────────────────────────────────
  if (config.get<boolean>('lsp.enable', true)) {
    const lsp = resolveCommand(config, 'ox-lsp', 'lsp.serverPath');
    outputChannel.appendLine(`LSP: ${lsp.command} ${lsp.args.join(' ')}`);

    const serverOptions: ServerOptions = {
      command: lsp.command,
      args: lsp.args,
      transport: TransportKind.stdio,
    };

    const clientOptions: LanguageClientOptions = {
      documentSelector: [{ scheme: 'file', language: 'oxybelis' }],
      synchronize: {
        fileEvents: vscode.workspace.createFileSystemWatcher('**/*.ox'),
      },
      outputChannel,
    };

    client = new LanguageClient('oxybelis', 'Oxybelis Language Server', serverOptions, clientOptions);

    try {
      await client.start();
      outputChannel.appendLine('LSP started');
    } catch (error) {
      outputChannel.appendLine(`LSP failed: ${error}`);
    }
  } else {
    outputChannel.appendLine('LSP disabled in settings');
  }

  // ── Formatter ─────────────────────────────────────────
  const fmt = resolveCommand(config, 'ox-fmt', 'formatter.serverPath');
  outputChannel.appendLine(`Formatter: ${fmt.command} ${fmt.args.join(' ')}`);

  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider('oxybelis', {
      async provideDocumentFormattingEdits(document: vscode.TextDocument): Promise<vscode.TextEdit[]> {
        const fileName = document.fileName;
        try {
          const formatted = execFileSync(fmt.command, [...fmt.args, fileName], {
            encoding: 'utf-8',
            timeout: 15000,
          });
          const fullRange = document.validateRange(new vscode.Range(0, 0, document.lineCount, 0));
          return [vscode.TextEdit.replace(fullRange, formatted)];
        } catch (err: unknown) {
          outputChannel.appendLine(`Format error: ${err instanceof Error ? err.message : String(err)}`);
          vscode.window.showErrorMessage(`Format failed: ${err instanceof Error ? err.message : String(err)}`);
          return [];
        }
      },
    })
  );

  // ── Commands ──────────────────────────────────────────
  const cc = resolveCommand(config, 'oxybelis', 'compiler.oxybelisPath');
  outputChannel.appendLine(`Compiler: ${cc.command} ${cc.args.join(' ')}`);

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.transpile', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;
      const fileName = editor.document.fileName;
      const outputFileName = fileName.replace(/\.ox$/, '.cpp');
      try {
        runTool(cc.command, [...cc.args, fileName, '-o', outputFileName]);
        vscode.window.showInformationMessage(`Transpiled to ${outputFileName}`);
      } catch (e) { vscode.window.showErrorMessage(`Transpile failed: ${e}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.check', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;
      const fileName = editor.document.fileName;
      try {
        const output = runTool(cc.command, [...cc.args, fileName, '--check']);
        outputChannel.appendLine(output);
        vscode.window.showInformationMessage('Type check passed');
      } catch (e: unknown) {
        outputChannel.appendLine(`Check errors:\n${e instanceof Error ? e.message : String(e)}`);
        vscode.window.showErrorMessage('Type check failed');
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.format', async () => {
      await vscode.commands.executeCommand('editor.action.formatDocument');
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.highlight', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;
      const fileName = editor.document.fileName;
      try {
        const output = runTool(cc.command, [...cc.args, fileName, '--highlight']);
        outputChannel.appendLine(output);
      } catch (e) { outputChannel.appendLine(`Highlight failed: ${e}`); }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.build', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;
      const fileName = editor.document.fileName;
      const baseName = path.basename(fileName, '.ox');
      try {
        const cppFile = baseName + '.cpp';
        const exeFile = baseName + '.exe';
        runTool(cc.command, [...cc.args, fileName, '-o', cppFile]);
        execFileSync('g++', ['-O3', '-std=c++20', cppFile, '-o', exeFile, '-lm'], {
          stdio: 'inherit', timeout: 60000,
        });
        vscode.window.showInformationMessage(`Build: ${exeFile}`);
      } catch (e) { vscode.window.showErrorMessage(`Build failed: ${e}`); }
    })
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) return undefined;
  return client.stop();
}
