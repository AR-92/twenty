import chalk from 'chalk';
import { execSync } from 'child_process';
import { Command } from 'commander';
import * as fs from 'fs-extra';

export class TestCommand {
  getCommand(): Command {
    const testCommand = new Command('test');
    testCommand
      .description('Run tests for the project')
      .option('-a, --all', 'Run all tests across all applications and libraries')
      .option('-f, --front', 'Run tests for frontend application only')
      .option('-b, --back', 'Run tests for backend application only')
      .option('-u, --unit', 'Run only unit tests')
      .option('-i, --integration', 'Run only integration tests')
      .option('-e, --e2e', 'Run end-to-end tests')
      .option('-w, --watch', 'Run tests in watch mode')
      .option('-c, --coverage', 'Generate coverage report')
      .option('--ci', 'Run tests in CI mode (no interactive prompts)')
      .action(async (options) => {
        await this.execute(options);
      });

    return testCommand;
  }

  async execute(options: { 
    all?: boolean; 
    front?: boolean; 
    back?: boolean; 
    unit?: boolean;
    integration?: boolean;
    e2e?: boolean;
    watch?: boolean;
    coverage?: boolean;
    ci?: boolean;
  }): Promise<void> {
    try {
      console.log(chalk.blue('🧪 Running tests...'));

      // Check if we're in the project root
      const isProjectRoot = await fs.pathExists('package.json') && await fs.pathExists('nx.json');
      
      if (!isProjectRoot) {
        console.error(chalk.red('❌ Not in a project root directory (missing package.json or nx.json)'));
        process.exit(1);
      }

      let testCmd = '';
      const testOptions = [];

      // Determine what to test based on options
      if (options.all || (!options.front && !options.back && !options.e2e)) {
        // Run all tests across all apps/libraries
        if (options.e2e) {
          testCmd = 'yarn nx run-many --target=test --projects=twenty-e2e-testing';
        } else {
          testCmd = 'yarn nx run-many --target=test --all';
        }
      } else {
        const projectsToTest = [];
        
        if (options.front) projectsToTest.push('twenty-front');
        if (options.back) projectsToTest.push('twenty-server');
        if (options.e2e) projectsToTest.push('twenty-e2e-testing');
        
        if (projectsToTest.length > 0) {
          testCmd = `yarn nx run-many --target=test --projects=${projectsToTest.join(',')}`;
        } else {
          console.log(chalk.yellow('⚠️  No specific target specified, running all tests...'));
          testCmd = 'yarn nx run-many --target=test --all';
        }
      }

      // Add test type filters
      if (options.unit) {
        testOptions.push('--unitTestRunner=jest');
      } else if (options.integration) {
        testOptions.push('--testType=integration');
      }

      // Add other options
      if (options.watch) {
        testOptions.push('--watch');
      }
      
      if (options.coverage) {
        testOptions.push('--coverage');
      }
      
      if (options.ci) {
        testOptions.push('--ci --maxWorkers=3');
      }

      const finalCmd = testOptions.length > 0 
        ? `${testCmd} ${testOptions.join(' ')}` 
        : testCmd;

      console.log(chalk.blue(`🚀 Running: ${finalCmd}`));
      
      // Execute the test command
      execSync(finalCmd, { stdio: 'inherit' });

      console.log(chalk.green('✅ Tests completed successfully!'));
      
      if (options.coverage) {
        console.log(chalk.blue('📋 Coverage report generated'));
      }
    } catch (error) {
      console.error(chalk.red('❌ Tests failed:'), error instanceof Error ? error.message : error);
      process.exit(1);
    }
  }
}