/**
 * App Theme Configuration
 * Based on React Native Paper
 */

import { MD3LightTheme as DefaultTheme } from 'react-native-paper';

export const theme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    // Red - Primary actions, selected items, navigation
    primary: '#E53935', // Main red
    // Green - Add buttons, success states
    secondary: '#4CAF50', // Main green
    tertiary: '#4ECDC4',
    error: '#E53935', // Red for errors
    background: '#FFFFFF',
    surface: '#F5F5F5',
    text: '#000000',
    textSecondary: '#666666',
    border: '#E0E0E0',
    success: '#4CAF50', // Green for success
    warning: '#FF9800',
    info: '#2196F3',
  },
  roundness: 12,
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
  },
  typography: {
    fontFamily: {
      regular: 'System',
      medium: 'System',
      bold: 'System',
    },
    fontSize: {
      xs: 12,
      sm: 14,
      md: 16,
      lg: 18,
      xl: 20,
      xxl: 24,
    },
  },
};

export type AppTheme = typeof theme;

