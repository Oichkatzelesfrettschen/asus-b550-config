# Branch Protection Recommendations

This document outlines recommended branch protection rules for the asus-b550-config repository to maintain code quality and security.

## Overview

Branch protection rules help maintain code quality by enforcing checks before code is merged. These rules should be configured in GitHub repository settings under Settings → Branches → Branch protection rules.

## Recommended Rules for `main` Branch

### 1. Require Pull Request Reviews

**Setting**: Require a pull request before merging

**Configuration**:
- ✅ Require approvals: 1 (for solo maintainer) or 2+ (for team)
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require review from Code Owners (if CODEOWNERS file exists)

**Why**: Ensures code is reviewed before merging, catching potential issues early.

### 2. Require Status Checks

**Setting**: Require status checks to pass before merging

**Required Checks**:
- ✅ `lint / ShellCheck (Shell Script Linting)`
- ✅ `lint / Markdownlint (Markdown Linting)`
- ✅ `lint / EditorConfig Check`
- ✅ `build / Build C Code (nct-id utility)`
- ✅ `build / Validate PKGBUILD (Arch Package)`
- ✅ `build / Validate Shell Scripts (Syntax)`
- ✅ `build / Validate Systemd Units`
- ✅ `documentation / Check Markdown Links`
- ✅ `documentation / Validate Example Configurations`
- ✅ `documentation / Check Documentation Completeness`
- ✅ `security / CodeQL Security Analysis`
- ✅ `security / ShellCheck Security Issues`

**Additional Settings**:
- ✅ Require branches to be up to date before merging
- ✅ Require status checks to pass before merging

**Why**: Ensures all automated tests and validations pass before code is merged.

### 3. Require Conversation Resolution

**Setting**: Require conversation resolution before merging

**Why**: Ensures all review comments are addressed before merging.

### 4. Require Signed Commits

**Setting**: Require signed commits

**Why**: Verifies the authenticity of commits and prevents impersonation.

**Setup**: Contributors need to configure GPG signing:
```bash
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_GPG_KEY_ID
```

### 5. Require Linear History

**Setting**: Require linear history

**Why**: Keeps the commit history clean and easy to follow. Forces rebase instead of merge commits.

### 6. Include Administrators

**Setting**: Include administrators

**Why**: Even repository administrators must follow the same rules, ensuring consistency.

### 7. Restrict Who Can Push

**Setting**: Restrict who can push to matching branches

**Allowed**:
- Repository administrators
- Specific teams or users (if applicable)

**Why**: Prevents accidental direct pushes to protected branches.

### 8. Allow Force Pushes

**Setting**: Do not allow force pushes

**Why**: Prevents rewriting history on protected branches, maintaining integrity.

### 9. Allow Deletions

**Setting**: Do not allow deletions

**Why**: Prevents accidental deletion of protected branches.

## Recommended Rules for `develop` Branch

Apply the same rules as `main`, but you may relax some requirements:

- Require approvals: 1 (can be lower than main)
- May allow force pushes: Only for maintainers during active development
- May skip some status checks: If iterating quickly

## Branch Naming Conventions

Enforce branch naming through settings or documentation:

**Recommended Pattern**:
```
<type>/<short-description>

Types:
- feature/   : New features
- fix/       : Bug fixes  
- docs/      : Documentation changes
- refactor/  : Code refactoring
- test/      : Test additions or changes
- chore/     : Maintenance tasks
- security/  : Security patches
- copilot/   : AI-assisted changes (existing pattern)
```

**Examples**:
- `feature/dual-sensor-support`
- `fix/rpm-calculation-error`
- `docs/update-installation-guide`

## CODEOWNERS File

Create a `.github/CODEOWNERS` file to automatically request reviews:

```
# Default owner for everything
* @Oichkatzelesfrettschen

# Specific owners for different areas
/docs/ @Oichkatzelesfrettschen
/scripts/ @Oichkatzelesfrettschen
/.github/ @Oichkatzelesfrettschen

# Require review for CI/CD changes
/.github/workflows/ @Oichkatzelesfrettschen

# Require review for security-sensitive files
SECURITY.md @Oichkatzelesfrettschen
/.github/workflows/security.yml @Oichkatzelesfrettschen
```

## Status Check Requirements

### Must Pass Before Merge

All checks from these workflows must pass:
1. Lint workflow
2. Build & Test workflow
3. Documentation workflow
4. Security workflow (for PRs and scheduled runs)

### Optional/Informational

- Release workflow (only runs on tags)
- Dependabot checks (reviewed separately)

## Implementing These Rules

### Step-by-Step Guide

1. **Navigate to Settings**
   - Go to repository Settings → Branches

2. **Add Branch Protection Rule**
   - Click "Add rule"
   - Branch name pattern: `main`

3. **Configure Required Checks**
   - Enable "Require status checks to pass before merging"
   - Search and select all workflow jobs listed above
   - Enable "Require branches to be up to date before merging"

4. **Configure Pull Request Requirements**
   - Enable "Require a pull request before merging"
   - Set "Required number of approvals before merging"
   - Enable "Dismiss stale pull request approvals when new commits are pushed"

5. **Configure Additional Settings**
   - Enable "Require conversation resolution before merging"
   - Enable "Require signed commits" (optional but recommended)
   - Enable "Require linear history"
   - Enable "Include administrators"
   - Disable "Allow force pushes"
   - Disable "Allow deletions"

6. **Save Changes**
   - Click "Create" or "Save changes"

7. **Repeat for Other Branches**
   - Create similar rules for `develop` if used
   - Adjust requirements as needed

## Testing Branch Protection

After configuring:

1. **Create a test PR**:
   ```bash
   git checkout -b test/branch-protection
   echo "test" >> README.md
   git add README.md
   git commit -m "test: verify branch protection"
   git push origin test/branch-protection
   ```

2. **Verify**:
   - PR cannot be merged until checks pass
   - PR cannot be merged without approval (if required)
   - Direct pushes to `main` are blocked

3. **Clean up**:
   - Close and delete the test PR/branch

## Monitoring and Maintenance

### Regular Reviews

- **Monthly**: Review branch protection rules for effectiveness
- **Quarterly**: Update required status checks as workflows change
- **After incidents**: Adjust rules to prevent recurrence

### Metrics to Track

- Number of PRs merged without violations
- Time from PR creation to merge
- Number of failed status checks
- Number of conversations requiring resolution

## Exceptions and Overrides

### When to Override

Branch protection can be temporarily disabled for:
- Emergency hotfixes (document in commit message)
- Repository maintenance (batch updates)
- Breaking out of deadlock situations

### How to Override

1. Repository administrators can override protections
2. Document the reason in the commit/PR
3. Re-enable protections immediately after
4. Review the change in next team meeting

## Resources

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- [Status Checks Documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks)
- [CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [Signed Commits Guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)

---

**Last Updated**: 2025-11-02  
**Maintained By**: Repository maintainers
