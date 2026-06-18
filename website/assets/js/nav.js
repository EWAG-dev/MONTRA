// Highlight active nav link based on current page
document.addEventListener('DOMContentLoaded', function() {
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  const navLinks = document.querySelectorAll('a[href$=".html"]');
  
  console.log('Current page:', currentPage);
  console.log('Found nav links:', navLinks.length);
  
  navLinks.forEach(link => {
    const href = link.getAttribute('href');
    console.log('Checking link:', href, 'vs', currentPage, 'Match:', href === currentPage);
    
    if (href === currentPage || (currentPage === '' && href === 'index.html')) {
      console.log('Activating:', href);
      link.classList.add('active-nav');
    }
  });
});
