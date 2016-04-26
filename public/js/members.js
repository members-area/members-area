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

/*$(function() {
  $('ul#side-menu').metisMenu();
});

$(function() {
  $(window).bind("load resize", function() {
    var topOffset = 50;
    var width = (this.window.innerWidth > 0) ? this.window.innerWidth : this.window.width;
    if (width < 768) {
      $('ul#side-menu').addClass('collapse');
      topOffset = 100;
    } else {
      $('ul#side-menu').removeClass('collapse');
    }

    var height = ((this.window.innerHeight > 0) ? this.window.innerHeight : this.window.height) - 1;
    height = height - topOffset;
    if (height < 1) height = 1;
    if (height > topOffset) {
      $('#main.container').css("min-height", (height) + "px");
    }
  });
  var url = window.location;
  var element = $('ul.nav a').filter(function() {
    return this.href == url;
  }).addClass('active').parent().parent().addClass('in').parent();
  if (element.is('li')) {
    element.addClass('active');
  }
});*/
