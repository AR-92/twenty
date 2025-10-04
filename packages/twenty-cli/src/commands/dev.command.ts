import chalk from 'chalk';
import { execSync, spawn } from 'child_process';
import { Command } from 'commander';
import * as fs from 'fs-extra';

export class DevCommand {
  private processes: Array<{ name: string; process: any }> = [];

  getCommand(): Command {
    const devCommand = new Command('dev');
    devCommand
      .description('Start development mode for the entire project')
      .option('-s, --services', 'Start required services (PostgreSQL, Redis, etc.)')
      .option('-f, --front', 'Start frontend development server only')
      .option('-b, --back', 'Start backend development server only')
      .option('--no-front', 'Skip frontend development server')
      .option('--no-back', 'Skip backend development server')
      .action(async (options) => {
        await this.execute(options);
      });

    return devCommand;
  }

  async execute(options: { 
    services?: boolean; 
    front?: boolean; 
    back?: boolean 
  }): Promise<void> {
    try {
      console.log(chalk.blue('🚀 Starting Twenty development mode...'));

      // Check if we're in the project root
      const isProjectRoot = await fs.pathExists('package.json') && await fs.pathExists('nx.json');
      
      if (!isProjectRoot) {
        console.error(chalk.red('❌ Not in a project root directory (missing package.json or nx.json)'));
        process.exit(1);
      }

      // Start required services if requested
      if (options.services) {
        await this.startServices();
      }

      // Determine what to start based on options
      const shouldStartFront = options.front !== false; // defaults to true unless explicitly disabled
      const shouldStartBack = options.back !== false;   // defaults to true unless explicitly disabled

      const promises: Promise<void>[] = [];

      if (shouldStartBack) {
        promises.push(this.startBackend());
      }

      if (shouldStartFront) {
        promises.push(this.startFrontend());
      }

      // Wait for both to start (non-blocking)
      await Promise.all(promises);

      console.log(chalk.green('✅ Development servers started!'));
      console.log(chalk.blue('🎯 Frontend: http://localhost:3000'));
      console.log(chalk.blue('🎯 Backend: http://localhost:3001'));
      
      // Keep the process alive
      this.setupGracefulShutdown();
    } catch (error) {
      console.error(chalk.red('❌ Development mode failed:'), error instanceof Error ? error.message : error);
      this.killAllProcesses();
      process.exit(1);
    }
  }

  private async startServices(): Promise<void> {
    console.log(chalk.blue('🐳 Starting required services...'));

    try {
      // Check if docker is available
      execSync('docker --version', { stdio: 'pipe' });
    } catch (error) {
      console.error(chalk.red('❌ Docker is required to start services but is not available'));
      process.exit(1);
    }

    // Start services defined in the Makefile
    const services = [
      'postgres-on-docker',
      'redis-on-docker',
      'clickhouse-on-docker',
    ];

    for (const service of services) {
      console.log(chalk.blue(`➙ Starting ${service}...`));
      execSync(`make ${service}`, { stdio: 'pipe' });
    }

    console.log(chalk.green('✅ Required services started'));
  }

  private async startBackend(): Promise<void> {
    console.log(chalk.blue(' ↑ Starting backend server...'));
    
    const backendProcess = spawn('yarn', ['nx', 'serve', 'twenty-server'], {
      stdio: 'inherit',
      shell: true
    });

    this.processes.push({ name: 'backend', process: backendProcess });

    backendProcess.on('error', (err) => {
      console.error(chalk.red('❌ Backend server error:'), err);
    });
  }

  private async startFrontend(): Promise<void> {
    console.log(chalk.blue(' ↓ Starting frontend server...'));
    
    const frontendProcess = spawn('yarn', ['nx', 'serve', 'twenty-front'], {
      stdio: 'inherit',
      shell: true
    });

    this.processes.push({ name: 'frontend', process: frontendProcess });

    frontendProcess.on('error', (err) => {
      console.error(chalk.red('❌ Frontend server error:'), err);
    });
  }

  private setupGracefulShutdown(): void {
    process.on('SIGINT', () => {
      console.log(chalk.yellow('\n🛑 Shutting down development servers...'));
      this.killAllProcesses();
      process.exit(0);
    });

    process.on('SIGTERM', () => {
      console.log(chalk.yellow('\n🛑 Shutting down development servers...'));
      this.killAllProcesses();
      process.exit(0);
    });
  }

  private killAllProcesses(): void {
    for (const proc of this.processes) {
      if (!proc.process.killed) {
        proc.process.kill();
      }
    }
    this.processes = [];
  }
}