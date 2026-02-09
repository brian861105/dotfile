# Justfile for automating GitHub update when .zshrc is modified

# Path to your actual .zshrc (symlink target)
ZSHRC := "zsh/.zshrc"

# Commit message template
COMMIT_MSG := "chore: update .zshrc"

default:
    @echo "Usage: just update-zshrc"

# Update GitHub when .zshrc is modified
update-zshrc:
    git add {{ZSHRC}}
    git commit -m {{COMMIT_MSG}} || echo "No changes to commit."
    git push
