# Why Twenty CLI?

A comprehensive command-line interface to develop, build, test, deploy, and manage Twenty CRM applications and the entire project

## Installation

```bash
npm install -g twenty-cli
```

## Requirements
- yarn >= 4.9.2
- Node.js >= 24.5.0
- Docker (for services and containerized development)
- an `apiKey`. Go to `https://twenty.com/settings/api-webhooks` to generate one

## Project Development Commands

The CLI now supports complete project development workflows:

### Project Setup and Dependencies
```bash
# Install all project dependencies
twenty install

# Clean install (removes node_modules first)
twenty install --clean
```

### Development Mode
```bash
# Start development mode with all services
twenty dev --services

# Start development with only frontend
twenty dev --front

# Start development with only backend
twenty dev --back

# Start development without services (if already running)
twenty dev
```

### Building the Project
```bash
# Build the entire project
twenty build --all

# Build only frontend
twenty build --front

# Build only backend
twenty build --back

# Build for production
twenty build --prod

# Build with statistics
twenty build --stats
```

### Running Tests
```bash
# Run all tests
twenty test --all

# Run only unit tests
twenty test --unit

# Run only integration tests
twenty test --integration

# Run end-to-end tests
twenty test --e2e

# Run tests in watch mode
twenty test --watch

# Generate coverage report
twenty test --coverage

# Run tests in CI mode
twenty test --ci
```

### Docker Management
```bash
# Start all required services using Docker
twenty docker services --start

# Stop all services
twenty docker services --stop

# Check service status
twenty docker services --status

# Run project in Docker
twenty docker up

# Stop project in Docker
twenty docker down

# Show service logs
twenty docker --logs

# Clean all Docker resources
twenty docker --clean
```

## Application Development Commands

For developing custom applications that extend Twenty CRM:

```bash
# Authenticate using your apiKey (CLI will prompt for your <apiKey>)
twenty auth login

# Init a new application called hello-world
twenty app init hello-world

# Go to your app
cd hello-world

# Add a serverless function to your application
twenty app add serverlessFunction

# Add a trigger to your serverless function
twenty app add trigger

# Add axios to your application
yarn add axios

# Start dev mode: automatically syncs changes to your Twenty workspace, so you can test new functions/objects instantly.
twenty app dev

# Or use one time sync
twenty app sync

# List all available commands
twenty help
```

## Application Structure

Each application in this package follows the standard application structure:

```
app-name/
├── package.json
├── README.md
├── serverlessFunctions  # Custom backend logic (runs on demand)
└── ...
```

## Publish your application

Applications are currently stored in twenty/packages/twenty-apps.

You can share your application with all twenty users.

```bash
# pull twenty project
git clone https://github.com/twentyhq/twenty.git
cd twenty

# create a new branch
git checkout -b feature/my-awesome-app
```

- copy your app folder into twenty/packages/twenty-apps
- commit your changes and open a pull request on https://github.com/twentyhq/twenty

```bash
git commit -m "Add new application"
git push
```

Our team reviews contributions for quality, security, and reusability before merging.

## Contributing

- see our [Hacktoberfest 2025 notion page](https://twentycrm.notion.site/Hacktoberfest-27711d8417038037a149d4638a9cc510) 
- our [Discord](https://discord.gg/cx5n4Jzs57)
