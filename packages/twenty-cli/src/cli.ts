#!/usr/bin/env node

import chalk from 'chalk';
import { Command } from 'commander';
import { AppCommand } from './commands/app.command';
import { AuthCommand } from './commands/auth.command';
import { ConfigCommand } from './commands/config.command';
import { ConfigAdminCommand } from './commands/config-admin.command';
import { CompanyCommand } from './commands/company.command';
import { PersonCommand } from './commands/person.command';
import { OpportunityCommand } from './commands/opportunity.command';
import { TaskCommand } from './commands/task.command';
import { NoteCommand } from './commands/note.command';
import { AttachmentCommand } from './commands/attachment.command';
import { UserCommand } from './commands/user.command';
import { UserAdminCommand } from './commands/user-admin.command';
import { ViewCommand } from './commands/view.command';
import { WorkspaceCommand } from './commands/workspace.command';
import { WorkspaceAdminCommand } from './commands/workspace-admin.command';
import { SettingsCommand } from './commands/settings.command';
import { EmailCommand } from './commands/email.command';
import { SystemCommand } from './commands/system.command';
import { FeatureFlagCommand } from './commands/feature-flag.command';
import { ApiKeyCommand } from './commands/api-key.command';
import { WebhookCommand } from './commands/webhook.command';
import { ServerAdminCommand } from './commands/server-admin.command';
import { AuditSecurityCommand } from './commands/audit-security.command';
import { InstallCommand } from './commands/install.command';
import { DevCommand } from './commands/dev.command';
import { BuildCommand } from './commands/build.command';
import { TestCommand } from './commands/test.command';
import { DockerCommand } from './commands/docker.command';

const program = new Command();

program
  .name('twenty')
  .description('CLI for Twenty CRM and application development')
  .version('0.1.0');

program.option(
  '--api-url <url>',
  'Twenty API URL',
  process.env.TWENTY_API_URL || 'http://localhost:3000',
);

program.addCommand(new AuthCommand().getCommand());
program.addCommand(new AppCommand().getCommand());
program.addCommand(new ConfigCommand().getCommand());
program.addCommand(new ConfigAdminCommand().getCommand());
program.addCommand(new CompanyCommand().getCommand());
program.addCommand(new PersonCommand().getCommand());
program.addCommand(new OpportunityCommand().getCommand());
program.addCommand(new TaskCommand().getCommand());
program.addCommand(new NoteCommand().getCommand());
program.addCommand(new AttachmentCommand().getCommand());
program.addCommand(new UserCommand().getCommand());
program.addCommand(new UserAdminCommand().getCommand());
program.addCommand(new ViewCommand().getCommand());
program.addCommand(new WorkspaceCommand().getCommand());
program.addCommand(new WorkspaceAdminCommand().getCommand());
program.addCommand(new SettingsCommand().getCommand());
program.addCommand(new EmailCommand().getCommand());
program.addCommand(new SystemCommand().getCommand());
program.addCommand(new FeatureFlagCommand().getCommand());
program.addCommand(new ApiKeyCommand().getCommand());
program.addCommand(new WebhookCommand().getCommand());
program.addCommand(new ServerAdminCommand().getCommand());
program.addCommand(new AuditSecurityCommand().getCommand());

// Project development commands
program.addCommand(new InstallCommand().getCommand());
program.addCommand(new DevCommand().getCommand());
program.addCommand(new BuildCommand().getCommand());
program.addCommand(new TestCommand().getCommand());
program.addCommand(new DockerCommand().getCommand());

program.exitOverride();

try {
  program.parse();
} catch (error) {
  if (error instanceof Error) {
    console.error(chalk.red('Error:'), error.message);
    process.exit(1);
  }
}
