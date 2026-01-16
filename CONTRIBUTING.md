# Contributing to Waybar Timer

Thank you for your interest in contributing to the Waybar Timer project! This document provides guidelines and information for contributors.

## Ways to Contribute

- **Report Bugs**: Found a bug? [Open an issue](https://github.com/nirabyte/waybar-timer/issues) with detailed information
- **Suggest Features**: Have an idea? [Open an issue](https://github.com/nirabyte/waybar-timer/issues) describing your feature request
- **Code Contributions**: Submit pull requests with improvements, bug fixes, or new features
- **Documentation**: Help improve documentation, README, or create tutorials

## Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/nirabyte/waybar-timer.git
   cd waybar-timer
   ```

2. **Test locally**:
   ```bash
   # Make sure the script is executable
   chmod +x timer.sh

   # Test basic functionality
   ./timer.sh --help  # if implemented
   ./timer.sh 10s     # test a 10 second timer
   ```

## Code Style Guidelines

### Bash Script Standards

- **Shebang**: Use `#!/bin/bash` at the top
- **Comments**: Use clear, descriptive comments for complex logic
- **Functions**: Use descriptive function names with `snake_case`
- **Variables**: Use `UPPER_CASE` for constants, `lower_case` for variables
- **Error Handling**: Use proper error handling and exit codes
- **Portability**: Prefer POSIX-compliant bash features

### Code Structure

```
#!/bin/bash

# Configuration section at top
CONFIG_VAR="value"

# Helper functions
helper_function() {
    # Implementation
}

# Main logic
main() {
    # Implementation
}

# Script execution
main "$@"
```

## Testing

### Manual Testing

Test these scenarios:
- Basic timer functionality (`./timer.sh 5m`)
- Pomodoro mode (`./timer.sh pomo`)
- Mouse click simulation (`./timer.sh click`)
- Edge cases (invalid input, interruptions)

### Testing Checklist

- [ ] Timer starts and counts down correctly
- [ ] Pause/resume functionality works
- [ ] Pomodoro mode transitions work
- [ ] Sound notifications play (if available)
- [ ] Script handles interruptions gracefully
- [ ] Waybar integration and persistance works properly

## Pull Request Process

1. **Fork the repository** and create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the code style guidelines

3. **Test thoroughly** before submitting

4. **Update documentation** if needed (README.md, etc.)

5. **Submit a pull request** with:
   - Clear title describing the change
   - Detailed description of what was changed and why
   - Reference any related issues

### PR Requirements

- Code follows the established style guidelines
- All tests pass
- Documentation is updated if needed
- Commit messages are clear and descriptive
- Changes are focused and not overly broad

## Commit Message Guidelines

Use clear, descriptive commit messages:

```
feat: add new timer preset for 90 minutes
fix: resolve issue with pomodoro break notifications
docs: update installation instructions
```

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help maintain a positive community
- Respect differing viewpoints and experiences

## Questions?

If you have questions about contributing, feel free to:
- Open a [GitHub Discussion](https://github.com/nirabyte/waybar-timer/discussions)
- Comment on existing issues
- Reach out to maintainers

Thank you for helping make Waybar Timer better! 