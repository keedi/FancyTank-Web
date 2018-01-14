(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function (e) {
      var action   = $(this).data("action");
      var filename = $(this).data("filename");
      var source   = $("#ft-template").html();
      var template = Handlebars.compile(source);

      var context;
      if (action === "delete") {
        context  = {
          title:        "Delete folder?",
          body:         'Are you sure you want to delete <span class="ft-modal-filename">' + filename + '</span> from your ' + CONFIG.site_name_short + '?',
          button_label: "Delete",
          button_class: "ft-button-delete"
        };
      }
      else if (action === "rename") {
        context  = {
          title:        "Rename folder?",
          body:         'Are you sure you want to rename <span class="ft-modal-filename">' + filename + '</span> from your ' + CONFIG.site_name_short + '?',
          button_label: "Rename",
          button_class: "ft-button-rename"
        };
      }
      else {
        return;
      }
      var html = template(context);

      $("#ft-modal-confirm").remove();
      $(".ft-modal").html(html);
      $("#ft-modal-confirm").modal("show");
    });

    $(document).on("click", ".ft-button-delete", function (e) {
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

