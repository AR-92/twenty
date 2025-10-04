import chalk from 'chalk';
import { execSync } from 'child_process';
import { Command } from 'commander';
import * as fs from 'fs-extra';

export class InstallCommand {
  getCommand(): Command {
    const installCommand = new Command('install');
    installCommand
      .description('Install all project dependencies')
      .option('-g, --global', 'Install globally with yarn')
      .option('-c, --clean', 'Clean existing node_modules before installing')
      .action(async (options) => {
        await this.execute(options);
      });

    return installCommand;
  }

  async execute(options: { global?: boolean; clean?: boolean }): Promise<void> {
    try {
      console.log(chalk.blue('📦 Installing project dependencies...'));

      // Check if we're in the project root (has package.json and nx.json)
      const isProjectRoot = await fs.pathExists('package.json') && await fs.pathExists('nx.json');
      
      if (!isProjectRoot) {
        console.error(chalk.red('❌ Not in a project root directory (missing package.json or nx.json)'));
        process.exit(1);
      }

      if (options.clean) {
        console.log(chalk.yellow('🧹 Cleaning existing node_modules...'));
        await fs.remove('node_modules');
        
        // Also clean workspace node_modules if they exist
        const workspaceNodeModules = '../../node_modules';
        if (await fs.pathExists(workspaceNodeModules)) {
          await fs.remove(workspaceNodeModules);
        }
      }

      // Determine the correct install command
      let installCmd = 'yarn install';
      if (options.global) {
        installCmd = 'yarn install --immutable';
      }

      console.log(chalk.blue(`🚀 Running: ${installCmd}`));
      
      // Execute the installation command
      execSync(installCmd, { stdio: 'inherit' });

      console.log(chalk.green('✅ Dependencies installed successfully!'));
      
      // Additional setup for development
      console.log(chalk.blue('🔧 Running additional setup...'));
      execSync('yarn nx run-many --target=build --all', { stdio: 'pipe' }).toString();
      
      console.log(chalk.green('✅ Project setup completed!'));
    } catch (error) {
      console.error(chalk.red('❌ Installation failed:'), error instanceof Error ? error.message : error);
      process.exit(1);
    }
  }
}