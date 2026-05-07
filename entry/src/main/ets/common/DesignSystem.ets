export interface Spacing {
  xxs: number;
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
  xxl: number;
}

export interface Radius {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
  full: number;
}

export interface TypographyStyle {
  size: number;
  weight: FontWeight;
}

export interface Typography {
  title_lg: TypographyStyle;
  title_md: TypographyStyle;
  title_sm: TypographyStyle;
  body_lg: TypographyStyle;
  body_md: TypographyStyle;
  body_sm: TypographyStyle;
  caption: TypographyStyle;
  label: TypographyStyle;
}

export interface ShadowStyle {
  radius: number;
  color: string;
  offsetY: number;
  offsetX: number;
}

export interface Shadows {
  sm: ShadowStyle;
  md: ShadowStyle;
  lg: ShadowStyle;
}

export const SPACING: Spacing = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48
};

export const RADIUS: Radius = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  full: 999
};

export const TYPOGRAPHY: Typography = {
  title_lg: { size: 28, weight: FontWeight.Bold },
  title_md: { size: 24, weight: FontWeight.Bold },
  title_sm: { size: 20, weight: FontWeight.Medium },
  body_lg: { size: 18, weight: FontWeight.Regular },
  body_md: { size: 16, weight: FontWeight.Regular },
  body_sm: { size: 14, weight: FontWeight.Regular },
  caption: { size: 12, weight: FontWeight.Regular },
  label: { size: 12, weight: FontWeight.Medium }
};

export const SHADOW: Shadows = {
  sm: { radius: 4, color: 'rgba(0,0,0,0.06)', offsetY: 2, offsetX: 0 },
  md: { radius: 8, color: 'rgba(0,0,0,0.10)', offsetY: 4, offsetX: 0 },
  lg: { radius: 16, color: 'rgba(0,0,0,0.14)', offsetY: 8, offsetX: 0 }
};

export enum Breakpoint {
  COMPACT = 'compact',
  MEDIUM = 'medium',
  EXPANDED = 'expanded'
}

export function getBreakpoint(widthVp: number): Breakpoint {
  if (widthVp < 600) {
    return Breakpoint.COMPACT;
  } else if (widthVp < 840) {
    return Breakpoint.MEDIUM;
  } else {
    return Breakpoint.EXPANDED;
  }
}

export function getWindowWidth(): number {
  try {
    return AppStorage.get<number>('windowWidth') ?? 360;
  } catch {
    return 360;
  }
}
