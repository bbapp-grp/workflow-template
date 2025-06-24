# Example Workflow Files

This directory contains example workflow files that microservices can copy and customize for their specific needs.

## Basic Examples

- `nodejs-development.yml` - Basic Node.js development workflow
- `nodejs-release.yml` - Basic Node.js release workflow
- `python-development.yml` - Python microservice development workflow
- `python-release.yml` - Python microservice release workflow
- `go-development.yml` - Go microservice development workflow
- `go-release.yml` - Go microservice release workflow

## Advanced Examples

- `advanced-nodejs-development.yml` - Node.js with custom build steps
- `advanced-nodejs-release.yml` - Node.js with custom release configuration

## Usage

1. Copy the appropriate example files to your microservice's `.github/workflows/` directory
2. Update the `service_name` to match your microservice name
3. Customize any optional parameters as needed
4. Commit and push to test the workflow

## Customization Tips

- Always update `service_name` to match your microservice
- Adjust `node_version` if you need a specific Node.js version
- Set `enable_tests: false` if you handle testing in your Dockerfile
- Customize `test_command` and `build_command` for your project structure
- Update `dockerfile_path` if your Dockerfile is not in the root directory
