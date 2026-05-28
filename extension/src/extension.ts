import * as vscode from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient/node';
import * as path from 'path';
import * as fs from 'fs';
import { execSync, execFileSync } from 'child_process';

let client: LanguageClient;
const outputChannel = vscode.window.createOutputChannel('Oxybelis');

function resolveFromPath(name: string): string | null {
  try {
    const isWin = process.platform === 'win32';
    const result = execSync(isWin ? `where.exe ${name}` : `which ${name}`, {
      encoding: 'utf-8',
      timeout: 5000,
    });
    const paths = result.trim().split(/\r?\n/);
    for (const p of paths) {
      const ext = path.extname(p).toLowerCase();
      if (isWin && ext === '.bat') continue;
      if (isWin && ext === '.cmd') continue;
      if (fs.existsSync(p)) return p;
    }
    return null;
  } catch {
    return null;
  }
}

function findBinary(extensionPath: string, name: string): string | null {
  const isWin = process.platform === 'win32';
  const candidates = [
    path.join(extensionPath, '..', 'dist', 'release', name + '.exe'),
    path.join(extensionPath, '..', 'dist', 'release', name),
    path.join(extensionPath, 'bin', name + '.exe'),
    path.join(extensionPath, 'bin', name),
    path.join(process.env.LOCALAPPDATA || '', 'oxybelis', 'bin', name + (isWin ? '.exe' : '')),
    path.join(process.env.HOME || process.env.USERPROFILE || '', '.oxybelis', 'bin', name),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return resolveFromPath(name);
}

function findScript(extensionPath: string, script: string): string | null {
  const p = path.join(extensionPath, '..', script);
  return fs.existsSync(p) ? p : null;
}

function resolveLspCommand(extensionPath: string, config: vscode.WorkspaceConfiguration): { command: string; args: string[] } {
  const userPath = config.get<string>('lsp.serverPath', '');
  if (userPath) {
    const resolved = path.isAbsolute(userPath) ? userPath : path.join(extensionPath, userPath);
    if (fs.existsSync(resolved)) return { command: resolved, args: [] };
  }

  const binary = findBinary(extensionPath, 'ox-lsp');
  if (binary) return { command: binary, args: [] };

  const pythonPath = config.get<string>('lsp.pythonPath', 'python');
  const script = findScript(extensionPath, 'ox_lsp.py');
  if (script) return { command: pythonPath, args: [script] };

  return { command: 'ox-lsp', args: [] };
}

function resolveFormatterCommand(extensionPath: string): { command: string; args: string[] } | null {
  const binary = findBinary(extensionPath, 'ox-fmt');
  if (binary) return { command: binary, args: [] };

  const pythonPath = 'python';
  const script = findScript(extensionPath, 'ox_fmt.py');
  if (script) return { command: pythonPath, args: [script] };

  return null;
}

function resolveCompilerCommand(extensionPath: string, config: vscode.WorkspaceConfiguration): { command: string; args: string[] } {
  const userPath = config.get<string>('compiler.oxybelisPath', '');
  if (userPath) {
    const resolved = path.isAbsolute(userPath) ? userPath : path.join(extensionPath, userPath);
    if (fs.existsSync(resolved)) return { command: resolved, args: [] };
  }

  const binary = findBinary(extensionPath, 'oxybelis');
  if (binary) return { command: binary, args: [] };

  const pythonPath = config.get<string>('compiler.pythonPath', 'python');
  const script = findScript(extensionPath, 'oxybelis.py');
  if (script) return { command: pythonPath, args: [script] };

  return { command: 'oxybelis', args: [] };
}

function runTool(cmd: string, args: string[], input?: string): string {
  return execFileSync(cmd, args, {
    encoding: 'utf-8',
    stdio: input ? ['pipe', 'pipe', 'pipe'] : ['inherit', 'pipe', 'pipe'],
    input,
    timeout: 30000,
  });
}

function getFileName(editor: vscode.TextEditor): vscode.Uri | null {
  if (editor.document.uri.scheme !== 'file') {
    vscode.window.showErrorMessage('File must be saved to disk first');
    return null;
  }
  return editor.document.uri;
}

export async function activate(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('oxybelis');
  outputChannel.appendLine(`Extension path: ${context.extensionPath}`);

  const lsp = resolveLspCommand(context.extensionPath, config);
  outputChannel.appendLine(`LSP command: ${lsp.command} ${lsp.args.join(' ')}`);

  if (config.get<boolean>('lsp.enable', true) && (lsp.command !== 'ox-lsp' || resolveFromPath('ox-lsp'))) {
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
      outputChannel.appendLine('Oxybelis language server started successfully');
    } catch (error) {
      outputChannel.appendLine(`Error starting language server: ${error}`);
      vscode.window.showWarningMessage(`Oxybelis LSP failed to start: ${error}`);
    }
  } else {
    outputChannel.appendLine('Oxybelis LSP disabled or binary not found');
  }

  registerFormatter(context);
  registerCommands(context);
}

function registerFormatter(context: vscode.ExtensionContext) {
  const fmt = resolveFormatterCommand(context.extensionPath);
  if (!fmt) {
    outputChannel.appendLine('ox-fmt not found — formatting unavailable');
    return;
  }
  outputChannel.appendLine(`Formatter command: ${fmt.command} ${fmt.args.join(' ')}`);

  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider('oxybelis', {
      async provideDocumentFormattingEdits(document: vscode.TextDocument): Promise<vscode.TextEdit[]> {
        const fileName = document.fileName;
        const source = document.getText();
        try {
          const result = execFileSync(fmt.command, [...fmt.args, '--check', fileName], {
            encoding: 'utf-8',
            stdio: ['pipe', 'pipe', 'pipe'],
            input: source,
            timeout: 15000,
          });
          return [];
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          try {
            const formatted = execFileSync(fmt.command, [...fmt.args, fileName], {
              encoding: 'utf-8',
              timeout: 15000,
            });
            const fullRange = document.validateRange(new vscode.Range(0, 0, document.lineCount, 0));
            return [vscode.TextEdit.replace(fullRange, formatted)];
          } catch (fmtErr: unknown) {
            outputChannel.appendLine(`Format failed: ${fmtErr instanceof Error ? fmtErr.message : String(fmtErr)}`);
            vscode.window.showErrorMessage(`Format failed: ${fmtErr instanceof Error ? fmtErr.message : String(fmtErr)}`);
            return [];
          }
        }
      },
    })
  );
}

function registerCommands(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('oxybelis');
  const cc = resolveCompilerCommand(context.extensionPath, config);
  outputChannel.appendLine(`Compiler command: ${cc.command} ${cc.args.join(' ')}`);

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.transpile', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const uri = getFileName(editor);
      if (!uri) return;

      const fileName = uri.fsPath;
      const outputFileName = fileName.replace(/\.ox$/, '.cpp');

      try {
        runTool(cc.command, [...cc.args, fileName, '-o', outputFileName]);
        vscode.window.showInformationMessage(`Transpiled to ${outputFileName}`);
        outputChannel.appendLine(`Transpiled: ${fileName} → ${outputFileName}`);
      } catch (error) {
        vscode.window.showErrorMessage(`Transpilation failed: ${error}`);
        outputChannel.appendLine(`Error: ${error}`);
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.check', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const uri = getFileName(editor);
      if (!uri) return;

      const fileName = uri.fsPath;
      try {
        const output = runTool(cc.command, [...cc.args, fileName, '--check']);
        outputChannel.appendLine(output);
        vscode.window.showInformationMessage('Type check passed');
      } catch (error: unknown) {
        outputChannel.appendLine(`Type check errors:\n${error instanceof Error ? error.message : String(error)}`);
        vscode.window.showErrorMessage('Type check failed');
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.format', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      await vscode.commands.executeCommand('editor.action.formatDocument');
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.highlight', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const uri = getFileName(editor);
      if (!uri) return;

      const fileName = uri.fsPath;
      try {
        const output = runTool(cc.command, [...cc.args, fileName, '--highlight']);
        outputChannel.appendLine(output);
      } catch (error) {
        outputChannel.appendLine(`Highlight failed: ${error}`);
        vscode.window.showErrorMessage('Highlight failed');
      }
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.build', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const uri = getFileName(editor);
      if (!uri) return;

      const fileName = uri.fsPath;
      const baseName = path.basename(fileName, '.ox');

      try {
        const cppFile = baseName + '.cpp';
        const exeFile = baseName + '.exe';

        outputChannel.appendLine(`Transpiling ${fileName}...`);
        runTool(cc.command, [...cc.args, fileName, '-o', cppFile]);

        outputChannel.appendLine(`Compiling ${cppFile} → ${exeFile}...`);
        execFileSync('g++', ['-O3', '-std=c++20', cppFile, '-o', exeFile, '-lm'], {
          stdio: 'inherit',
          timeout: 60000,
        });

        vscode.window.showInformationMessage(`Build successful: ${exeFile}`);
      } catch (error) {
        vscode.window.showErrorMessage(`Build failed: ${error}`);
        outputChannel.appendLine(`Build error: ${error}`);
      }
    })
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) return undefined;
  return client.stop();
}
