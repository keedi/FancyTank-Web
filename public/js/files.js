(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function () {
      var filename = $(this).data('filename');
      $(".modal-body .ft-modal-filename").text( filename );
    });

    $(document).on("click", ".ft-button-delete", function () {
      console.log("delete button is clicked");
      /**
       * delete
       */
      // ...
      $('#ft-modal-confirm').modal('hide');
    });

  });
}).call(this);

