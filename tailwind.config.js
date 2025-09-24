/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      fontSize: {
        'xs': ['14px', '20px'],    // was 12px/16px, now 14px/20px
        'sm': ['16px', '24px'],    // was 14px/20px, now 16px/24px
        'base': ['18px', '28px'],  // was 16px/24px, now 18px/28px
        'lg': ['20px', '28px'],    // was 18px/28px, now 20px/28px
        'xl': ['22px', '30px'],    // was 20px/28px, now 22px/30px
      }
    },
  },
  plugins: [],
}