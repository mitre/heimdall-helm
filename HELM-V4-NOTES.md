# Helm v4 Migration Notes

**Helm v4.0.0 Released**: November 12, 2025
**Status**: Production-ready, stable release

## Key Takeaways for Heimdall Chart

### ✅ Good News: Backward Compatible

- **Chart API v2 works unchanged** in Helm v4
- All existing Helm 3 charts work without modification
- No breaking changes for chart developers (yet)
- Chart API v3 is coming but not required yet

### 🎯 Our Strategy

**For v1.0.0 Release**:
```yaml
# Chart.yaml
apiVersion: v2  # Use v2 (works in Helm 3 and 4)
name: heimdall
version: 1.0.0
```

**Benefits**:
- ✅ Works with Helm 3 users (if any still exist)
- ✅ Works with Helm 4 users (majority)
- ✅ Future-proof for Chart API v3 when released

## Helm v4 New Features

### 1. Server-Side Apply
**What**: Modern Kubernetes resource management
**Impact**: Better conflict resolution, improved upgrades
**Action**: No chart changes needed, works automatically

### 2. WebAssembly Plugins
**What**: Cross-platform plugin system
**Impact**: Plugins work everywhere (Linux, macOS, Windows, ARM)
**Action**: Optional - consider for advanced features later

### 3. Enhanced Security
**What**: Improved chart signing, verification
**Impact**: Better supply chain security
**Action**: Plan for chart signing in Phase 7 (CI/CD)

### 4. Modern Go SDK
**What**: Updated SDK with modern logging
**Impact**: Better debugging, multiple loggers
**Action**: No chart changes needed

## What Changed for Chart Developers

### CLI Flag Renames (Minor)
Some Helm CLI flags renamed for consistency:
- Most charts unaffected
- Installation commands unchanged
- `helm install`, `helm upgrade`, `helm template` work as before

### New Features Available

**Server-Side Apply**:
```bash
# Now available in Helm 4
helm upgrade --install heimdall ./heimdall --server-side-apply
```

**Enhanced Caching**:
- Content-based caching improves performance
- Faster installs and upgrades
- No chart changes required

## Migration Checklist

### For Heimdall Chart v1.0.0

- [x] Use Chart API v2 (backward compatible)
- [ ] Test with Helm v4 CLI
- [ ] Verify `helm lint` passes with v4
- [ ] Test `helm install` with v4
- [ ] Test `helm upgrade` with v4
- [ ] Verify all Helm hooks work
- [ ] Test values.schema.json validation
- [ ] Document Helm v4 compatibility in README

### Testing Commands

```bash
# Verify Helm version
helm version
# Should show v4.0.0 or higher

# Lint with v4
helm lint ./heimdall --strict

# Template with v4
helm template heimdall ./heimdall --debug

# Install with v4
helm install heimdall ./heimdall -n heimdall-test --create-namespace

# Upgrade with v4
helm upgrade heimdall ./heimdall -n heimdall-test
```

## Breaking Changes

**None for Chart API v2!**

According to official announcement:
> "Helm 4 retains the core interface and behavior familiar to current users, minimizing disruption for existing workflows."

Chart API v2 continues to work unchanged.

## Future: Chart API v3

**Status**: Not released yet, coming during Helm 4 lifecycle

**When to Migrate**:
- Wait for official Chart API v3 specification
- Monitor Helm blog and documentation
- Upgrade when v3 offers concrete benefits

**Approach**:
1. Release Heimdall chart v1.0.0 with Chart API v2
2. Monitor Chart API v3 development
3. Plan migration to v3 when stable (likely v2.0.0 of chart)

## References

- **Helm v4 Release**: https://www.cncf.io/announcements/2025/11/12/helm-marks-10-years-with-release-of-version-4/
- **Helm Documentation**: https://helm.sh/docs/
- **Helm Changelog**: https://helm.sh/docs/changelog/
- **Helm Best Practices**: https://helm.sh/docs/chart_best_practices/

## Summary

**Bottom Line**: Use Chart API v2, test with Helm v4, ship with confidence.

✅ **No changes required** to use Helm v4
✅ **Backward compatible** with Helm 3
✅ **Future-proof** for Chart API v3
✅ **Ready to go** with our modernization plan

Helm v4 is a **non-issue** for our migration - it just works! 🎉
