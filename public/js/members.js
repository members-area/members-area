(function ($, window) {

  function loadRetinaImages() {
    var pixelRatio = (typeof window.devicePixelRatio == 'number') ? 
      window.devicePixelRatio : 
      1;
    
    if (pixelRatio > 1) {
      $('img[data-retina-src]').each(function () {
        $(this).attr('src', $(this).data('retina-src'));
      });
    }
  }

  // Set up event listener for list style changer
  function initPeopleListTypeSelector() {
    var
      $listTypeSelector = $('#list-type-selector'),
      $list = $('#' + $listTypeSelector.data('list'));

    $listTypeSelector.find('input[name=list-type]').on('change', function() {
      $list.toggleClass('grid', $(this).filter(':checked').val() === 'grid');
    });
  }

  $(function () {
     loadRetinaImages();
     initPeopleListTypeSelector();
  });

}(this.jQuery, this));

