# Justfile for automating GitHub update when .zshrc is modified

# Path to your actual .zshrc (symlink target)
default:
    @echo "Usage: just update-zshrc"

# Update GitHub when .zshrc is modified
ZSHRC := "zsh/.zshrc"

update-zshrc:
    git add {{ZSHRC}}
    git commit -m "chore: update .zshrc" || echo "No changes to commit."
    git push
