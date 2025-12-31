// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
document.addEventListener("DOMContentLoaded", function() {
  const toggleBtn = document.getElementById("detective-toggle-btn");
  const detectiveWindow = document.getElementById("detective-window");

  if (toggleBtn && detectiveWindow) {
    toggleBtn.addEventListener("click", function() {
      detectiveWindow.classList.toggle("detective-hidden");
    });
  }
});