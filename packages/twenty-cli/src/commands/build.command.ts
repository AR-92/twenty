import chalk from 'chalk';
import { execSync } from 'child_process';
import { Command } from 'commander';
import * as fs from 'fs-extra';

export class BuildCommand {
  getCommand(): Command {
    const buildCommand = new Command('build');
    buildCommand
      .description('Build the entire project or specific applications')
      .option('-a, --all', 'Build all applications and libraries')
      .option('-f, --front', 'Build frontend application only')
      .option('-b, --back', 'Build backend application only')
      .option('-c, --cli', 'Build CLI application only')
      .option('--prod', 'Build for production (with optimizations)')
      .option('--stats', 'Generate build statistics')
      .action(async (options) => {
        await this.execute(options);
      });

    return buildCommand;
  }

  async execute(options: { 
    all?: boolean; 
    front?: boolean; 
    back?: boolean; 
    cli?: boolean;
    prod?: boolean;
    stats?: boolean;
  }): Promise<void> {
    try {
      console.log(chalk.blue('🏗️  Building project...'));

      // Check if we're in the project root
      const isProjectRoot = await fs.pathExists('package.json') && await fs.pathExists('nx.json');
      
      if (!isProjectRoot) {
        console.error(chalk.red('❌ Not in a project root directory (missing package.json or nx.json)'));
        process.exit(1);
      }

      let buildCmd = '';
      const buildOptions = [];

      // Determine what to build based on options
      if (options.all || (!options.front && !options.back && !options.cli)) {
        buildCmd = 'yarn nx run-many --target=build --all';
      } else {
        const projectsToBuild = [];
        
        if (options.front) projectsToBuild.push('twenty-front');
        if (options.back) projectsToBuild.push('twenty-server');
        if (options.cli) projectsToBuild.push('twenty-cli');
        
        if (projectsToBuild.length > 0) {
          buildCmd = `yarn nx run-many --target=build --projects=${projectsToBuild.join(',')}`;
        } else {
          console.log(chalk.yellow('⚠️  No specific target specified, building all...'));
          buildCmd = 'yarn nx run-many --target=build --all';
        }
      }

      // Add production flag if needed
      if (options.prod) {
        buildOptions.push('--configuration=production');
      }

      // Add stats flag if needed
      if (options.stats) {
        buildOptions.push('--stats');
      }

      const finalCmd = buildOptions.length > 0 
        ? `${buildCmd} ${buildOptions.join(' ')}` 
        : buildCmd;

      console.log(chalk.blue(`🚀 Running: ${finalCmd}`));
      
      // Execute the build command
      execSync(finalCmd, { stdio: 'inherit' });

      console.log(chalk.green('✅ Build completed successfully!'));
      
      // Additional info based on build type
      if (options.prod) {
        console.log(chalk.blue('📦 Production build ready for deployment'));
      } else {
        console.log(chalk.blue('🔧 Development build ready'));
      }
    } catch (error) {
      console.error(chalk.red('❌ Build failed:'), error instanceof Error ? error.message : error);
      process.exit(1);
    }
  }
}