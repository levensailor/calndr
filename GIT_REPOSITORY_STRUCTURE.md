# Git Repository Structure Summary

## Current Setup:

### 1. Main Repository: /Users/levensailor/Dev/calndr
- **Git Remote**: https://github.com/levensailor/calndr.git
- **Purpose**: Integrated iOS app + backend development
- **Contents**: 
  - iOS app (ios/)
  - Backend with medical API fixes (backend/)
  - All deployment scripts and migrations
  - Integrated development environment

### 2. Refactored Backend Repository: /Users/levensailor/Dev/calndr-backend-refactor  
- **Git Remote**: https://github.com/levensailor/calndrclub.git
- **Purpose**: Standalone backend deployment and advanced features
- **Contents**:
  - Refactored backend structure
  - Docker and Terraform configurations
  - Advanced deployment scripts
  - Same medical API fixes applied

## Workflow:
1. **iOS + Backend Development**: Use /Users/levensailor/Dev/calndr
2. **Backend-only Features**: Use /Users/levensailor/Dev/calndr-backend-refactor  
3. **Critical Fixes**: Apply to both repositories (as we just did)

## Status: ✅ Both repositories now have the same medical API fixes
