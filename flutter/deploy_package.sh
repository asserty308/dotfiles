#!/bin/bash

# Deployment helper script.
#
# How to call:
# ./deploy_package.sh [-v x.y.z|--version x.y.z]

usage() {
  echo "Usage: $0 [-v <new-version>|--version <new-version>]"
}

CURRENT_VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')

if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Current version in pubspec.yaml must be in format X.Y.Z"
  exit 1
fi

IFS='.' read -r CURRENT_MAJOR CURRENT_MINOR CURRENT_PATCH <<< "$CURRENT_VERSION"
NEW_VERSION="$CURRENT_MAJOR.$CURRENT_MINOR.$((CURRENT_PATCH + 1))"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      if [ -z "$2" ]; then
        echo "Error: Missing value for $1"
        usage
        exit 1
      fi
      NEW_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument '$1'"
      usage
      exit 1
      ;;
  esac
done

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in format X.Y.Z"
  exit 1
fi

# format code before deployment
dart format lib test

# commit any changes before deployment
git add .
git commit -m "style: format code before deployment"
git push origin main

# run tests before deployment. exit when tests fail
flutter test
if [ $? -ne 0 ]; then
    echo -e "\033[31mTests failed. Please fix the issues before deploying.\033[0m"
    exit 1
fi

# Update pubspec.yaml (only change the 'version:' line)
sed -i.bak "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
rm pubspec.yaml.bak

echo "Updated pubspec.yaml to version $NEW_VERSION"

# Commit changes
git add pubspec.yaml
git commit -m "chore: bump version to $NEW_VERSION"

# Create git tag
TAG="v$NEW_VERSION"
git tag -a "$TAG" -m "Release $TAG"

git push
git push --tags

echo "Created git tag $TAG and pushed changes to remote repository"

# Documentation
dart doc .
