$(document).ready(function() {
  $('#select_all').click(function(event) {
    if(this.checked) {
      $('.checkbox_item').each(function() {
        this.checked = true;
      });
    } else {
      $('.checkbox_item').each(function() {
        this.checked = false;
      });
    };
  });
});
