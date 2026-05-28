import * as vscode from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient/node';
import * as path from 'path';
import * as fs from 'fs';
import { execSync } from 'child_process';

let client: LanguageClient;
const outputChannel = vscode.window.createOutputChannel('Oxybelis');

function findBinary(extensionPath: string, name: string): string | null {
  const candidates = [
    path.join(extensionPath, '..', 'dist', 'release', name + '.exe'),
    path.join(extensionPath, '..', 'dist', 'release', name),
    path.join(extensionPath, 'bin', name + '.exe'),
    path.join(extensionPath, 'bin', name),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
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
  return execSync(input ? `${cmd} ${args.join(' ')}` : `"${cmd}" ${args.join(' ')}`, {
    encoding: 'utf-8',
    stdio: input ? ['pipe', 'pipe', 'pipe'] : ['inherit', 'pipe', 'pipe'],
    input,
    timeout: 30000,
  });
}

export async function activate(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('oxybelis');

  if (!config.get<boolean>('lsp.enable', true)) {
    outputChannel.appendLine('Oxybelis LSP disabled in settings');
    return;
  }

  const lsp = resolveLspCommand(context.extensionPath, config);
  outputChannel.appendLine(`Starting Oxybelis language server: ${lsp.command} ${lsp.args.join(' ')}`);

  const serverOptions: ServerOptions = {
    command: lsp.command,
    args: lsp.args,
    transport: TransportKind.stdio
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'oxybelis' }],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/*.ox')
    },
    outputChannel
  };

  client = new LanguageClient('oxybelis', 'Oxybelis Language Server', serverOptions, clientOptions);

  try {
    await client.start();
    outputChannel.appendLine('Oxybelis language server started successfully');
  } catch (error) {
    outputChannel.appendLine(`Error starting language server: ${error}`);
    vscode.window.showErrorMessage(`Failed to start Oxybelis language server: ${error}`);
    throw error;
  }

  registerCommands(context);
}

function registerCommands(context: vscode.ExtensionContext) {
  const config = vscode.workspace.getConfiguration('oxybelis');
  const cc = resolveCompilerCommand(context.extensionPath, config);

  context.subscriptions.push(
    vscode.commands.registerCommand('oxybelis.transpile', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const fileName = editor.document.fileName;
      const outputFileName = fileName.replace(/\.ox$/, '.cpp');

      try {
        runTool(cc.command, [...cc.args, `"${fileName}"`, '-o', `"${outputFileName}"`]);
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

      const fileName = editor.document.fileName;
      try {
        const output = runTool(cc.command, [...cc.args, `"${fileName}"`, '--check']);
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
    vscode.commands.registerCommand('oxybelis.build', async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const fileName = editor.document.fileName;
      const baseName = path.basename(fileName, '.ox');

      try {
        const cppFile = baseName + '.cpp';
        const exeFile = baseName + '.exe';

        outputChannel.appendLine(`Transpiling ${fileName}...`);
        runTool(cc.command, [...cc.args, `"${fileName}"`, '-o', `"${cppFile}"`]);

        outputChannel.appendLine(`Compiling ${cppFile} → ${exeFile}...`);
        execSync(`g++ -O3 -std=c++20 "${cppFile}" -o "${exeFile}" -lm`, {
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
