# File Size Limits - CRITICAL RULE

## 🚨 MAXIMUM FILE SIZE: 400 lines per component

**This is a HARD LIMIT - no exceptions.**

## Why This Rule Exists

1. **Maintainability**: Files >400 lines become impossible to debug
2. **Team Collaboration**: Large files create merge conflicts
3. **Performance**: Smaller files compile faster and load quicker
4. **Testing**: Small components are easier to unit test
5. **Reusability**: Modular code can be reused across the application

## File Size Guidelines

### ✅ **GOOD** (Under 200 lines)
- Single responsibility
- Easy to understand at a glance
- Quick to debug and modify
- Perfect for unit testing

### ⚠️ **ACCEPTABLE** (200-400 lines)
- Complex but still manageable
- May need refactoring soon
- Acceptable for initial implementation

### ❌ **UNACCEPTABLE** (>400 lines)
- **MUST BE SPLIT IMMEDIATELY**
- Impossible to maintain
- Creates technical debt
- Blocks team productivity

## Component Splitting Strategy

### **When to Split:**
1. **Multiple responsibilities** → Create separate components
2. **Complex logic** → Extract to composables
3. **Large templates** → Break into sub-components
4. **Multiple features** → Separate feature components

### **How to Split:**
```
❌ BAD: One 800-line component
├── HugeComponent.vue (800 lines)

✅ GOOD: Multiple focused components
├── MainComponent.vue (150 lines)
├── FeatureA.vue (120 lines)
├── FeatureB.vue (110 lines)
├── FeatureC.vue (130 lines)
└── utils/composables.js (200 lines)
```

## Vue.js Specific Guidelines

### **Template Limits:**
- **Max 150 lines** of template code
- Use slots for reusable layouts
- Extract repeated markup to components

### **Script Limits:**
- **Max 200 lines** of script code
- Extract complex logic to composables
- Use utility functions for calculations

### **Style Limits:**
- **Max 100 lines** of scoped styles
- Use utility classes instead of custom CSS
- Extract common styles to global CSS

## Immediate Action Required

**Current Status Check:**
- PeriodOverviewCalendar.vue: ~580 lines → **MUST SPLIT**
- Break into: CalendarView.vue, CalendarHeader.vue, CalendarGrid.vue

## Splitting Checklist

Before creating any component, ask:
1. [ ] Will this exceed 400 lines?
2. [ ] Can I break this into smaller pieces?
3. [ ] Should I create sub-components first?
4. [ ] Can I extract logic to composables?

## Enforcement

**If you create a file >400 lines:**
1. **STOP immediately**
2. **Split the file** before continuing
3. **Review with team** before merging

## Benefits of Following This Rule

- **Faster Development**: Small files are quicker to work with
- **Better Debugging**: Easy to locate and fix issues
- **Team Happiness**: No one fights with 800-line files
- **Code Quality**: Natural pressure to write cleaner code
- **Scalability**: System grows without becoming unmaintainable

## Remember

**"If it's too big to understand in one screen, it's too big to exist."**

This rule protects our sanity and productivity. Thank you for following it!
