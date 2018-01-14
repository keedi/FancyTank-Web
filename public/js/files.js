(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function () {
      var filename = $(this).data('filename');
      $(".modal-body .ft-modal-filename").text( filename );
    });

  });
}).call(this);

