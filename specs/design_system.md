# Design System & UI Translation Guidelines

### 1. Visual Standard
- Ground Truth: The Admin prototype exported from Google AI Studio (`prototypes/react_reference/`) defines the visual style for both Web and Mobile.
- The Supervisor screens must use identical card styles, border radius, app bars, and color palettes as the Admin screens.

### 2. React to Flutter Component Mapping
When converting React UI from `prototypes/react_reference/` to Flutter:
- React `div` with flex row/column -> Flutter `Row` or `Column`
- Tailwind `rounded-xl`, `border`, `shadow-sm` -> Flutter `Card` with `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`
- React sidebar navigation -> Flutter `NavigationDrawer` or `NavigationRail`
- React modal dialogs -> Flutter `showDialog` with `AlertDialog`
- Status Badges (e.g. "Approved", "Pending", "On-site") -> Custom Flutter `Chip` or `Container` with rounded pill borders and matching opacity colors.

### 3. Theme Specifications (Extracted from Admin Prototype)

- Design Language: Material 3 (`useMaterial3: true`)
- Typography: Inter, Plus Jakarta Sans, or Roboto (clean, modern sans-serif)

#### Color Palette
- Backgrounds & Canvas:
  - App Canvas / Scaffold: Cool Light Gray (`#F8FAFC`)
  - Surface / Cards / Sidebar: Pure White (`#FFFFFF`)
  - Subtle Borders & Dividers: Border Slate (`#E2E8F0` / `#F1F5F9`)

- Brand & Primary Controls:
  - Primary Navy (Brand text, "Export Report" button): Deep Midnight Navy (`#0A194E` or `#0F172A`)
  - Accent / Active Blue (Active nav highlight, timeline dots): Electric Royal Blue (`#2563EB`)
  - Active Nav Background: Light Tint Blue (`#EFF6FF`) with right border indicator (`#2563EB`, 3dp width)
  - Secondary Action Button ("+ Add Area"): Pale Slate Gray (`#E2E8F0` or `#EAEEF4`), Text (`#334155`)

- Text Colors:
  - Primary Headings & Stats: Dark Navy / Slate 900 (`#0F172A`)
  - Secondary / Body Text: Slate 700 (`#334155`)
  - Muted / Column Headers / Subtitles: Slate 500 (`#64748B`)

- Status Pills & Alert Colors:
  - Optimal / Success (e.g., "OPTIMAL", stable trend):
    - Background: Soft Indigo / Blue-gray (`#E0E7FF` or `#DBEAFE`)
    - Text: Dark Indigo (`#3730A3` or `#1E40AF`)
  - Warning / Understaffed / Action Required:
    - Background: Pale Red / Rose (`#FEE2E2`)
    - Text: Crimson Red (`#991B1B` or `#B91C1C`)
    - Border (for critical alert cards): `#FECACA`
  - Neutral / Review / Stable:
    - Background: Light Gray (`#F1F5F9`)
    - Text: Slate Muted (`#475569`)
  - Counter Badges (Sidebar badges on "Leaves", "Notifications"):
    - Pill shape, Background: Pale Red (`#FEE2E2`), Text: Bright Red (`#DC2626`), Font size: 11sp bold

