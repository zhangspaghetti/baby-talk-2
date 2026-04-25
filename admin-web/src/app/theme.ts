import type { CSSProperties } from 'react';
import type { ThemeConfig } from 'antd';

export const warmPaperAdmin = {
  palette: {
    bgBase: '#FFF8F0',
    bgSurface: '#FFFFFF',
    bgSunken: '#F5F0EB',
    bgAccentSoft: '#FFF0E5',
    accent: '#FF8C42',
    accentDark: '#E67A30',
    accentLight: '#FFF0E5',
    info: '#3B8577',
    infoSoft: '#D4E8E3',
    success: '#6B8F5E',
    successSoft: '#E8F0E5',
    warning: '#E6A817',
    warningSoft: '#FFF5D9',
    error: '#D94B3C',
    errorSoft: '#FDE8E6',
    textPrimary: '#2D2926',
    textSecondary: '#6B5E57',
    textMuted: '#8A7D76',
    border: '#E6DDD6',
  },
  radius: {
    sm: 8,
    md: 16,
    lg: 24,
  },
  shadow: {
    sm: '0 1px 3px rgba(45, 41, 38, 0.06)',
    md: '0 2px 12px rgba(45, 41, 38, 0.08)',
    lg: '0 8px 24px rgba(45, 41, 38, 0.12)',
  },
  font: {
    body: '"PingFang SC", "Noto Sans SC", "Microsoft YaHei", sans-serif',
    data: '"DM Sans", "Segoe UI", "Helvetica Neue", Arial, sans-serif',
  },
} as const;

export const adminTheme: ThemeConfig = {
  token: {
    colorPrimary: warmPaperAdmin.palette.accent,
    colorLink: warmPaperAdmin.palette.accentDark,
    colorInfo: warmPaperAdmin.palette.info,
    colorSuccess: warmPaperAdmin.palette.success,
    colorWarning: warmPaperAdmin.palette.warning,
    colorError: warmPaperAdmin.palette.error,
    colorBgBase: warmPaperAdmin.palette.bgBase,
    colorBgLayout: warmPaperAdmin.palette.bgSunken,
    colorBgContainer: warmPaperAdmin.palette.bgSurface,
    colorBgElevated: warmPaperAdmin.palette.bgSurface,
    colorFillSecondary: warmPaperAdmin.palette.bgSunken,
    colorFillTertiary: warmPaperAdmin.palette.bgAccentSoft,
    colorBorderSecondary: warmPaperAdmin.palette.border,
    colorText: warmPaperAdmin.palette.textPrimary,
    colorTextSecondary: warmPaperAdmin.palette.textSecondary,
    colorTextTertiary: warmPaperAdmin.palette.textMuted,
    borderRadius: warmPaperAdmin.radius.md,
    borderRadiusSM: warmPaperAdmin.radius.sm,
    borderRadiusLG: warmPaperAdmin.radius.lg,
    boxShadowSecondary: warmPaperAdmin.shadow.md,
    fontFamily: warmPaperAdmin.font.body,
    fontFamilyCode: warmPaperAdmin.font.data,
  },
  components: {
    Layout: {
      bodyBg: warmPaperAdmin.palette.bgBase,
      headerBg: warmPaperAdmin.palette.bgSurface,
      siderBg: warmPaperAdmin.palette.bgSurface,
      triggerBg: warmPaperAdmin.palette.bgSurface,
      triggerColor: warmPaperAdmin.palette.textSecondary,
    },
    Card: {
      headerBg: 'transparent',
      borderRadiusLG: warmPaperAdmin.radius.md,
    },
    Menu: {
      itemBg: 'transparent',
      subMenuItemBg: 'transparent',
      itemColor: warmPaperAdmin.palette.textSecondary,
      itemHoverColor: warmPaperAdmin.palette.textPrimary,
      itemHoverBg: warmPaperAdmin.palette.bgAccentSoft,
      itemSelectedColor: warmPaperAdmin.palette.accentDark,
      itemSelectedBg: warmPaperAdmin.palette.bgAccentSoft,
      activeBarBorderWidth: 0,
      itemBorderRadius: warmPaperAdmin.radius.sm,
    },
    Button: {
      primaryShadow: 'none',
      defaultShadow: 'none',
      borderRadius: warmPaperAdmin.radius.sm,
    },
    Tag: {
      borderRadiusSM: warmPaperAdmin.radius.sm,
    },
    Alert: {
      withDescriptionPadding: 16,
    },
  },
};

export const adminSurfaceStyles: Record<string, CSSProperties> = {
  page: {
    minHeight: '100vh',
    background: warmPaperAdmin.palette.bgBase,
  },
  centeredPage: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    background: warmPaperAdmin.palette.bgBase,
  },
  frameCard: {
    boxShadow: warmPaperAdmin.shadow.md,
    border: `1px solid ${warmPaperAdmin.palette.border}`,
  },
};
