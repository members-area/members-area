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

  $(function() {

    $('ul#side-menu').metisMenu();

  });

  $(function() {
    $(window).bind("load resize", function() {
      var width = this.window.width();
      if (width < 768) {
        $('ul#side-menu').addClass('collapse');
      } else {
        $('ul#side-menu').removeClass('collapse');
      }
    });
    var url = window.location;
    var element = $('ul.nav a').filter(function() {
      return this.href == url;
    }).addClass('active').parent().parent().addClass('in').parent();
    if (element.is('li')) {
      element.addClass('active');
    }
  });

}(this.jQuery, this));
