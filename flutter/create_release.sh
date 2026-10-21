# Release creation script.
#
# Features:
# - Ensures you are on the main branch.
# - Ensures there are no uncommitted changes before creating a release.
# - Runs tests and stops on failure.
# - Increments the build number in pubspec.yaml when one is present.
# - Optionally sets an explicit app version name in pubspec.yaml.
#   Pass only the version name as x.y.z; the script preserves the existing version style.
#   Packages that use x.y.z+build keep their incremented build number.
#   Packages that use x.y.z keep that format unchanged.
#   When setting a version here, do not set the git tag manually; the script will tag it.
# - Formats code before release.
# - Commits and pushes changes made by formatting or versioning.
# - Creates and pushes a git tag based on the pubspec.yaml version.
#
# How to call:
# ./create_release.sh [--build|--patch|--minor|--major] [--version|-v [x.y.z]]

# make sure we are on main branch. exit when not
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    echo -e "\033[31mYou are not on the main branch. Please switch to main before creating a release.\033[0m"
    exit 1
fi

# make sure there are no uncommitted changes. exit when working tree is dirty
if [ -n "$(git status --porcelain)" ]; then
  echo -e "\033[31mYou have uncommitted changes. Please commit or stash them before creating a release.\033[0m"
  exit 1
fi

# format code before release
dart format lib test

# commit any changes before release
git add .
git commit -m "style: format code before release"
git push origin main

# run tests before release. exit when tests fail
flutter test
if [ $? -ne 0 ]; then
    echo -e "\033[31mTests failed. Please fix the issues before creating a release.\033[0m"
    exit 1
fi

# parse optional version name override
version_bump=false
version_value=""
bump_type=""
for ((i=1; i<=$#; i++)); do
  arg=${!i}
  case "$arg" in
    --build|--patch|--minor|--major)
      if [ -n "$bump_type" ] && [ "$bump_type" != "${arg#--}" ]; then
        echo -e "\033[31mChoose only one version bump argument.\033[0m"
        exit 1
      fi
      bump_type="${arg#--}"
      ;;
    --version|-v)
      next_index=$((i + 1))
      next_arg=${!next_index}
      if [ -n "$next_arg" ] && [[ ! "$next_arg" =~ ^- ]]; then
        version_value="$next_arg"
      else
        version_bump=true
      fi
      ;;
    --version=*)
      version_value="${arg#*=}"
      ;;
  esac
done

if [ -n "$bump_type" ] && [ -n "$version_value" ]; then
  echo -e "\033[31mUse either a version bump argument or --version, not both.\033[0m"
  exit 1
fi

current_version=$(grep '^version: ' pubspec.yaml | awk '{print $2}')
if [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\+([0-9]+))?$ ]]; then
  current_major="${BASH_REMATCH[1]}"
  current_minor="${BASH_REMATCH[2]}"
  current_patch="${BASH_REMATCH[3]}"
  current_version_name="${current_major}.${current_minor}.${current_patch}"
  has_build_number=false
  if [ -n "${BASH_REMATCH[5]}" ]; then
    has_build_number=true
    current_build="${BASH_REMATCH[5]}"
    new_build=$((current_build + 1))
  fi
else
  echo -e "\033[31mInvalid version format in pubspec.yaml. Expected x.y.z or x.y.z+build.\033[0m"
  exit 1
fi

if [ -n "$version_value" ]; then
  if [[ ! "$version_value" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo -e "\033[31mInvalid version format. Expected x.y.z.\033[0m"
    exit 1
  fi

  new_version_name="$version_value"
else
  new_version_name="$current_version_name"
fi

case "$bump_type" in
  patch)
    new_version_name="${current_major}.${current_minor}.$((current_patch + 1))"
    ;;
  minor)
    new_version_name="${current_major}.$((current_minor + 1)).0"
    ;;
  major)
    new_version_name="$((current_major + 1)).0.0"
    ;;
esac

if [ "$has_build_number" = true ]; then
  new_version="${new_version_name}+${new_build}"
else
  new_version="${new_version_name}"
fi

sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml
echo "Version set to ${new_version}"

git add .
if ! git diff --cached --quiet; then
  git commit -m "chore: bump version to ${new_version}"
  git push origin main
fi

# add version-tag from pubspec.yaml when not already present
version=$(grep '^version: ' pubspec.yaml | awk '{print $2}')
if ! git rev-parse "v$version" >/dev/null 2>&1; then
    git tag -a "v$version" -m "Release v$version"
    git push --tags
else
    echo -e "\033[31mTag v$version already exists. Increment version in pubspec.yaml to continue deployment.\033[0m"
    exit 1
fi
