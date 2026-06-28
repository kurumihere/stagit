#!/bin/bash
set -e
export PATH="/usr/local/bin:$PATH"

GITHUB_USER="kurumihere"
WEB_DIR="/var/www/code.kurumi.world"
GIT_DIR="/var/git"
URL_PREFIX="https://github.com/$GITHUB_USER/"

mkdir -p "$WEB_DIR"
mkdir -p "$GIT_DIR"

# Get all public repos for the user
REPOS=$(curl -s "https://api.github.com/users/$GITHUB_USER/repos?per_page=100" | jq -r '.[].name')

cd "$GIT_DIR"

for REPO in $REPOS; do
    # Clone or update the bare repository
    if [ -d "$REPO.git" ]; then
        echo "Updating $REPO.git..."
        cd "$REPO.git"
        git fetch origin "+refs/heads/*:refs/heads/*" --prune
        cd ..
    else
        echo "Cloning $REPO..."
        git clone --bare "https://github.com/$GITHUB_USER/$REPO.git" "$REPO.git"
    fi

    # Create description and owner files for stagit
    # We could fetch desc from GitHub API, but here's a simple way
    DESC=$(curl -s "https://api.github.com/repos/$GITHUB_USER/$REPO" | jq -r '.description // "No description"')
    echo "$DESC" > "$REPO.git/description"
    echo "$GITHUB_USER" > "$REPO.git/owner"
    echo "git@github.com:$GITHUB_USER/$REPO.git" > "$REPO.git/url"

    # Make stagit html
    mkdir -p "$WEB_DIR/$REPO"
    cd "$WEB_DIR/$REPO"
    
    # stagit requires being in the directory where files will be written
    stagit "$GIT_DIR/$REPO.git"
    
    # Create symlinks for stagit styles
    ln -sf /usr/local/share/doc/stagit/style.css .
    ln -sf /usr/local/share/doc/stagit/logo.png .
    ln -sf /usr/local/share/doc/stagit/favicon.png .
    
    cd "$GIT_DIR"
done

# Generate the index
cd "$WEB_DIR"
stagit-index $(find $GIT_DIR -maxdepth 1 -name "*.git") > index.html

echo "Done!"
