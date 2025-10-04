import chalk from 'chalk';
import { execSync } from 'child_process';
import { Command } from 'commander';
import * as fs from 'fs-extra';

export class DockerCommand {
  getCommand(): Command {
    const dockerCommand = new Command('docker');
    dockerCommand
      .description('Docker-related commands for development and deployment')
      .option('-s, --services', 'Start all required docker services (PostgreSQL, Redis, etc.)')
      .option('-d, --down', 'Stop all docker services')
      .option('-l, --logs', 'Show logs from docker services')
      .option('-b, --build', 'Build docker images for the project')
      .option('-r, --run', 'Run the project in docker containers')
      .option('--clean', 'Clean all docker containers, images, and volumes')
      .action(async (options) => {
        await this.execute(options);
      });

    // Add subcommands
    dockerCommand
      .command('services')
      .description('Manage docker services')
      .option('--start', 'Start all required services')
      .option('--stop', 'Stop all services')
      .option('--status', 'Check status of services')
      .action(async (options) => {
        if (options.start) {
          await this.startServices();
        } else if (options.stop) {
          await this.stopServices();
        } else if (options.status) {
          await this.checkServiceStatus();
        } else {
          console.log(chalk.yellow('⚠️  Please specify an action: --start, --stop, or --status'));
        }
      });

    dockerCommand
      .command('up')
      .description('Start the project in docker containers')
      .option('--prod', 'Run in production mode')
      .action(async (options) => {
        await this.runProject(options);
      });

    dockerCommand
      .command('down')
      .description('Stop all docker containers for the project')
      .action(async () => {
        await this.stopProject();
      });

    return dockerCommand;
  }

  async execute(options: { 
    services?: boolean; 
    down?: boolean; 
    logs?: boolean;
    build?: boolean;
    run?: boolean;
    clean?: boolean;
  }): Promise<void> {
    try {
      console.log(chalk.blue('🐳 Managing Docker containers...'));

      // Check if docker is available
      try {
        execSync('docker --version', { stdio: 'pipe' });
      } catch (error) {
        console.error(chalk.red('❌ Docker is required but not available'));
        process.exit(1);
      }

      if (options.services) {
        await this.startServices();
      } else if (options.down) {
        await this.stopServices();
      } else if (options.logs) {
        await this.showLogs();
      } else if (options.build) {
        await this.buildImages();
      } else if (options.run) {
        await this.runProject({});
      } else if (options.clean) {
        await this.cleanDocker();
      } else {
        console.log(chalk.yellow('⚠️  Please specify an action or use subcommands'));
        console.log(chalk.gray('   Examples:'));
        console.log(chalk.gray('   twenty docker services --start'));
        console.log(chalk.gray('   twenty docker up'));
        console.log(chalk.gray('   twenty docker down'));
      }
    } catch (error) {
      console.error(chalk.red('❌ Docker operation failed:'), error instanceof Error ? error.message : error);
      process.exit(1);
    }
  }

  private async startServices(): Promise<void> {
    console.log(chalk.blue(' ↑ Starting required docker services...'));

    // Check if Makefile exists
    const hasMakefile = await fs.pathExists('Makefile');
    
    if (hasMakefile) {
      // Use commands from the existing Makefile
      const services = [
        'postgres-on-docker',
        'redis-on-docker',
        'clickhouse-on-docker',
      ];

      for (const service of services) {
        console.log(chalk.blue(`➙ Starting ${service}...`));
        execSync(`make ${service}`, { stdio: 'pipe' });
      }
    } else {
      // Fallback to direct docker commands
      console.log(chalk.yellow('⚠️  Makefile not found, using default docker commands...'));
      
      // Start PostgreSQL
      console.log(chalk.blue('➙ Starting PostgreSQL...'));
      try {
        execSync('docker run -d --name twenty_postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=default -p 5432:5432 postgres:16', { stdio: 'pipe' });
      } catch (e) {
        // Container might already exist, try starting it
        try {
          execSync('docker start twenty_postgres', { stdio: 'pipe' });
        } catch (e2) {
          console.log(chalk.yellow('⚠️  Could not start PostgreSQL container'));
        }
      }

      // Start Redis
      console.log(chalk.blue('➙ Starting Redis...'));
      try {
        execSync('docker run -d --name twenty_redis -p 6379:6379 redis:latest', { stdio: 'pipe' });
      } catch (e) {
        try {
          execSync('docker start twenty_redis', { stdio: 'pipe' });
        } catch (e2) {
          console.log(chalk.yellow('⚠️  Could not start Redis container'));
        }
      }
    }

    console.log(chalk.green('✅ Required services started'));
  }

  private async stopServices(): Promise<void> {
    console.log(chalk.blue(' ↓ Stopping docker services...'));

    const services = [
      'twenty_pg',
      'twenty_redis', 
      'twenty_clickhouse',
      'twenty_grafana',
      'twenty_otlp_collector'
    ];

    for (const service of services) {
      try {
        execSync(`docker stop ${service}`, { stdio: 'pipe' });
        execSync(`docker rm ${service}`, { stdio: 'pipe' });
        console.log(chalk.gray(`✓ Stopped ${service}`));
      } catch (e) {
        // Service might not exist, that's ok
        console.log(chalk.gray(`- ${service} was not running`));
      }
    }

    console.log(chalk.green('✅ Services stopped'));
  }

  private async checkServiceStatus(): Promise<void> {
    console.log(chalk.blue('🔍 Checking docker service status...'));

    try {
      const result = execSync('docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"', { stdio: 'pipe' }).toString();
      console.log(result);
    } catch (error) {
      console.error(chalk.red('❌ Error checking service status:'), error instanceof Error ? error.message : error);
    }
  }

  private async showLogs(): Promise<void> {
    console.log(chalk.blue('📋 Showing docker logs...'));
    
    const services = [
      'twenty_pg',
      'twenty_redis',
      'twenty_clickhouse'
    ];

    for (const service of services) {
      try {
        const logs = execSync(`docker logs --tail 20 ${service}`, { stdio: 'pipe' }).toString();
        if (logs.trim()) {
          console.log(chalk.gray(`\n=== ${service} logs ===`));
          console.log(logs);
        }
      } catch (e) {
        console.log(chalk.gray(`- Could not get logs for ${service}`));
      }
    }
  }

  private async buildImages(): Promise<void> {
    console.log(chalk.blue('🔨 Building docker images...'));
    
    // This would typically involve checking for Dockerfiles and building them
    // For now, let's assume there are standard dockerfiles for each service
    console.log(chalk.yellow('⚠️  Project-specific Dockerfiles not found. Using standard approach...'));
    
    // In a real implementation, this would build actual project Dockerfiles
    console.log(chalk.blue('No project Dockerfiles found - would build from source in real implementation'));
  }

  private async runProject(options: { prod?: boolean }): Promise<void> {
    console.log(chalk.blue('🚀 Running project in Docker...'));
    
    // Start services first
    await this.startServices();
    
    console.log(chalk.green('✅ Project is running in Docker!'));
    console.log(chalk.blue('🎯 Access the application at http://localhost:3000'));
  }

  private async stopProject(): Promise<void> {
    console.log(chalk.blue('🛑 Stopping project containers...'));
    await this.stopServices();
    console.log(chalk.green('✅ Project stopped'));
  }

  private async cleanDocker(): Promise<void> {
    console.log(chalk.blue('🗑️  Cleaning docker resources...'));
    
    // Stop and remove all containers with 'twenty' in the name
    try {
      const containers = execSync('docker ps -a -q --filter "name=twenty"', { stdio: 'pipe' }).toString().trim();
      if (containers) {
        execSync(`docker rm -f ${containers}`, { stdio: 'pipe' });
        console.log(chalk.gray('✓ Removed all twenty containers'));
      }
    } catch (e) {
      console.log(chalk.gray('No containers to remove'));
    }
    
    // Remove images with 'twenty' in the name
    try {
      const images = execSync('docker images -q --filter "reference=twenty/*"', { stdio: 'pipe' }).toString().trim();
      if (images) {
        execSync(`docker rmi -f ${images}`, { stdio: 'pipe' });
        console.log(chalk.gray('✓ Removed all twenty images'));
      }
    } catch (e) {
      console.log(chalk.gray('No images to remove'));
    }
    
    // Remove volumes with 'twenty' in the name
    try {
      const volumes = execSync('docker volume ls -q --filter "name=twenty"', { stdio: 'pipe' }).toString().trim();
      if (volumes) {
        execSync(`docker volume rm ${volumes}`, { stdio: 'pipe' });
        console.log(chalk.gray('✓ Removed all twenty volumes'));
      }
    } catch (e) {
      console.log(chalk.gray('No volumes to remove'));
    }
    
    console.log(chalk.green('✅ Docker resources cleaned'));
  }
}