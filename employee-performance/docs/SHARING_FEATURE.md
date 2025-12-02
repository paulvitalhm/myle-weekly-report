# Shareable Report Feature - November 10, 2025

## Overview
Added mobile-optimized shareable reports with two sharing options:
1. **Share Link** - Copy shareable URL to send via text/email
2. **Download Image** - Generate PNG screenshot of report

## Key Features

### 1. Mobile-First Card Layout
Replaced desktop table with responsive card design optimized for mobile viewing:
- Performance Index cards show rank, tier, employee, index, date, and clients
- Each card stacks vertically on mobile
- Large, readable text
- Color-coded tier badges (Top/Good/Low)

### 2. Share Link Button
**Functionality:**
- Click "🔗 Share Report" button
- Copies shareable URL to clipboard: `https://your-domain.com/report/{periodId}`
- Shows "✓ Link Copied!" confirmation
- Anyone with link can view report (read-only)

**Use Case:**
```
Manager clicks Share → Gets URL → Sends via text message
Recipient opens on phone → Sees mobile-optimized report
No login required, no app navigation visible
```

### 3. Download Image Button
**Functionality:**
- Click "📸 Download Image" button
- Generates high-quality PNG (2x scale for retina displays)
- Downloads as `myle-report-{date}.png`
- Can be shared via text, email, or saved for records

**Technical:**
- Uses html2canvas library to capture report
- Captures entire scrollable report
- Background color preserved
- Fonts and colors rendered accurately

### 4. Hours Discrepancies Section Removed
- Commented out (not accurate enough yet)
- Can be re-enabled later when calculation improved
- Preserves code for future use

## Components

### ShareableReport.vue (New)
**Purpose:** Mobile-optimized report view with sharing capabilities

**Features:**
- Props: `periodId`, `isSharedView`
- Loads same data as PerformanceReport
- Card-based layout instead of table
- Action buttons (Share/Download) hidden in shared view
- Responsive design (mobile-first)

**Sections:**
1. Report Header (logo, title, period info)
2. Performance Index Cards (rank, tier, employee details)
3. Best Performing Team Card (green background)
4. Lowest Performing Team Card (red background)  
5. Footer (timestamp, branding)

### App.vue (Modified)
**Changes:**
- Imported ShareableReport instead of PerformanceReport
- Added `isSharedView={false}` prop
- Shows share/download buttons when viewing report from app

## Mobile Optimization

### Card Layout
```
┌─────────────────────────┐
│ #1           [Top Tier] │
├─────────────────────────┤
│ Employee: John Doe      │
│ Index: 52.50            │
│ Date: Mon, Nov 03 2025  │
│ Clients: Aaron, Lea     │
└─────────────────────────┘
```

### Responsive Breakpoints
- **Mobile (<768px)**:
  - Cards stack vertically
  - Full-width buttons
  - Labels/values stack vertically
  - Larger touch targets

- **Desktop (≥768px)**:
  - Same card layout (optimized for readability)
  - Buttons side-by-side
  - Max width 900px for comfort

## Installation & Setup

### 1. Install html2canvas
```bash
cd employee-performance
npm install html2canvas
```

### 2. Build & Deploy
```bash
npm run build
# Deploy dist/ folder to your hosting
```

### 3. Configure URLs
Share link URL format: `{your-domain}/report/{periodId}`

**Note:** For shareable links to work, you'll need to:
1. Deploy the app to a web server
2. Configure routing to handle `/report/:periodId` URLs
3. Set up Supabase for public read access on reports

## Usage Instructions

### For Managers/Users:

**Sharing via Link:**
1. Navigate to Reports view
2. Click "🔗 Share Report" button
3. Link copied automatically
4. Paste link in text message, email, WhatsApp, etc.
5. Recipient opens link on any device (no login needed)

**Sharing via Image:**
1. Navigate to Reports view
2. Click "📸 Download Image" button
3. Wait 2-3 seconds for generation
4. Image downloads to device
5. Share image file via text, email, or social media

### Best Practices:
- Review report before sharing
- Image is static snapshot (won't update with new data)
- Link shows live data (updates when period data changes)
- For compliance/records: Use image download
- For real-time sharing: Use link

## Technical Details

### Data Loading
- Same as PerformanceReport component
- Calls `get_performance_index` SQL function
- Detects teams and calculates performance
- No Hours Discrepancies calculation

### Image Generation
- **Library**: html2canvas (pure JavaScript, no dependencies)
- **Quality**: 2x scale (high DPI)
- **Format**: PNG
- **Size**: Varies based on content (~500KB-2MB)
- **Capture**: Entire report-content div

### Share Link Format
```javascript
const shareUrl = `${window.location.origin}/report/${periodId}`
// Example: https://myle-performance.com/report/123e4567-e89b-12d3-a456-426614174000
```

## Limitations & Future Enhancements

### Current Limitations:
1. **No Standalone Route Yet**: Share links require additional routing setup
2. **No Authentication Check**: Anyone with link can view (may want to add password protection)
3. **Static Image**: Downloaded image doesn't update with new data
4. **No PDF Export**: Only PNG format available

### Planned Enhancements:
1. **Standalone Share Route** (`/report/:id`)
   - No header/navigation
   - Just report content
   - Optional password protection

2. **PDF Export**
   - Multi-page support
   - Better print quality
   - Smaller file size

3. **Link Expiration**
   - Time-limited share links
   - Revocable access

4. **Custom Branding**
   - Add company logo to shared reports
   - Customizable colors/styling

5. **Share Analytics**
   - Track who viewed shared reports
   - View timestamps

## Security Considerations

### Current Setup (Open Access):
- No authentication required for shared links
- Period ID in URL (UUID - not guessable)
- Read-only access (no modifications possible)
- Supabase RLS disabled (development mode)

### Production Recommendations:
1. **Enable Supabase RLS** with read-only policy for reports
2. **Add Link Expiration** (e.g., 7 days, 30 days)
3. **Optional Password Protection** for sensitive reports
4. **Rate Limiting** to prevent abuse
5. **HTTPS Only** for secure transmission

## Testing Checklist

- [x] Build compiles successfully
- [ ] Share button copies link to clipboard
- [ ] Download button generates PNG image
- [ ] Mobile cards display correctly on phone
- [ ] Tier badges show correct colors
- [ ] Team cards show correct data
- [ ] Image download includes all report sections
- [ ] Report loads on mobile browsers (iOS/Android)
- [ ] No Hours Discrepancies section visible
- [ ] Performance data matches original report

## Files Modified

### New Files:
- `src/components/ShareableReport.vue` (580+ lines)

### Modified Files:
- `src/App.vue` - Imported ShareableReport
- `src/components/PerformanceReport.vue` - Commented out Hours Discrepancies
- `package.json` - Added html2canvas dependency

### Documentation:
- `docs/SHARING_FEATURE.md` (this file)

## Support & Troubleshooting

### "Link doesn't copy"
- Check browser clipboard permissions
- Try manual copy: Browser shows URL in fallback alert

### "Image download fails"
- Check browser console for errors
- Ensure all fonts/images loaded
- Try incognito mode (extensions can interfere)

### "Report doesn't display on mobile"
- Check screen width (designed for all sizes)
- Verify mobile browser compatibility
- Clear browser cache

### "Share link shows 404"
- Standalone route not yet implemented
- Use within app for now
- Future update will add `/report/:id` route

## Next Steps

1. Test sharing on actual mobile devices
2. Deploy to staging environment
3. Set up standalone share route
4. Configure Supabase for public read access
5. Add optional password protection
6. Implement link expiration
7. Add usage analytics
