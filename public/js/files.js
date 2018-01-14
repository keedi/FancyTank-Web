(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function () {
      var filename = $(this).data('filename');
      var source   = $("#entry-template").html()
      var template = Handlebars.compile(source);
      var context  = {
        title:        "Delete folder?",
        body:         'Are you sure you want to delete <span class="ft-modal-filename">' + filename + '</span> from your ' + CONFIG.site_name_short + '?',
        button_label: "Delete",
        button_class: "ft-button-delete"
      };
      var html = template(context);
      $(".ft-modal").html(html)
      $("#ft-modal-confirm").modal("show");
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

