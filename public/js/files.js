(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function () {
      var filename = $(this).data('filename');
      $(".modal-body .ft-modal-filename").text( filename );
    });

    $(document).on("click", ".ft-button-delete", function () {
      var filename = $(".modal-body .ft-modal-filename").text();
      var trFile   = $(".ft-button-popup[data-filename='" + filename + "']").closest("tr");
      var apiUrl   = trFile.data("api-url");

      /**
       * request to delete file on server
       */
      $.ajax({
	url: apiUrl + "/delete",
	type: "DELETE",
	success: function(result) {
          /**
           * hide from file explorer
           */
          trFile.remove();
	},
	error: function(jqXHR, textStatus, errorThrown) {
          $(".ft-error-api-msg").text(jqXHR.responseJSON.Message);
          $(".ft-error-api").show(400, function() {
            setTimeout(function() {
              $(".ft-error-api").fadeOut(600);
            }, 3000);
          });
	}
      });

      /**
       * hide modal
       */
      $('#ft-modal-confirm').modal('hide');
    });

  });
}).call(this);

