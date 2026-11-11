export type Theme = "dark" | "light";

export const THEME_COOKIE = "afriva_theme";
export const DEFAULT_THEME: Theme = "dark";

/**
 * Runs in <head> before first paint: applies the saved theme from the cookie so
 * static pages never flash the wrong colors.
 */
export const THEME_SCRIPT = `(function(){try{var m=document.cookie.match(/(?:^|; )${THEME_COOKIE}=(light|dark)/);document.documentElement.dataset.theme=m?m[1]:"${DEFAULT_THEME}"}catch(e){}})()`;
