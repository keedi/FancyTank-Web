(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function () {
      var filename = $(this).data('filename');
      $(".modal-body .ft-modal-filename").text( filename );
    });

    $(document).on("click", ".ft-button-delete", function () {
      /**
       * request to delete file on server
       */
      //...

      /**
       * hide from file explorer
       */
      var filename = $(".modal-body .ft-modal-filename").text();
      var trFile   = $(".ft-button-popup[data-filename=" + filename + "]").closest("tr");
      trFile.remove();

      /**
       * hide modal
       */
      $('#ft-modal-confirm').modal('hide');
    });

  });
}).call(this);

