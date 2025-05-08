// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import 'jquery'
import "timeago"

window.$ = window.jQuery = jquery;
console.log("Turbo loaded!");
$(document).on("turbo:load", () => {
    console.log("Turbo loaded!");
});
  