(function() {
  $(function() {

    $(document).on("click", ".ft-button-popup", function (e) {
      var action   = $(this).data("action");
      var $trFile  = $(this).closest("tr");
      var filename = $trFile.data("filename");
      var isDir    = $trFile.data("is-directory");
      var source   = $("#ft-template").html();
      var template = Handlebars.compile(source);

      var fileType = "File";
      if ( isDir === true )
        fileType = "Directory";

      var context;
      if (action === "delete") {
        bodyHtml
          = '<div class="ft-modal-data" data-filename="' + filename + '">'
          + '  Are you sure you want to delete <span class="ft-modal-filename">' + filename + '</span> from your ' + CONFIG.site_name_short + '?'
          + "</div>"
          ;

        context  = {
          title:        "Delete " + fileType + "?",
          body:         bodyHtml,
          button_label: "Delete",
          button_class: "ft-button-delete"
        };
      }
      else if (action === "rename") {
        bodyHtml
          = '<div class="ft-modal-data" data-filename="' + filename + '">'
          + '  <div class="form-group">'
          + "    <label>Enter the file name to be changed.</label>"
          + '    <input class="form-control ft-modal-dest-filename" placeholder="Enter text" value="' + filename + '" autofocus="autofocus">'
          + "  </div>"
          + "</div>"
          ;

        context  = {
          title:        "Rename " + fileType + "?",
          body:         bodyHtml,
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

      var dotIdx = filename.lastIndexOf(".");
      $(".ft-modal-dest-filename")[0].setSelectionRange(0, dotIdx);

      // FIXME : doesn't work now
      //$(".ft-modal-dest-filename").focus();
    });

    $(document).on("click", ".ft-button-delete", function (e) {
      var filename = $(".modal-body .ft-modal-data").data("filename");
      var $trFile  = $(".ft-table-row-file[data-filename='" + filename + "']");
      var apiUrl   = $trFile.data("api-url");

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
          $trFile.remove();
        },
        error: function(jqXHR, textStatus, errorThrown) {
          $(".ft-error-api-msg").text(jqXHR.responseJSON.message);
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

    $(document).on("click", ".ft-button-rename", function (e) {
      var filename     = $(".modal-body .ft-modal-data").data("filename");
      var destFilename = $(".ft-modal-dest-filename").val();
      var $trFile      = $(".ft-table-row-file[data-filename='" + filename + "']");
      var apiUrl       = $trFile.data("api-url");

      /**
       * request to delete file on server
       */
      $.ajax({
        url: apiUrl + "/rename",
        type: "PUT",
        data: { filename: destFilename },
        success: function(result) {
          if (result.isSameDir === 1) {
            // rename
            $trFile.find(".ft-media-cell-filename span").text(destFilename);
          }
          else {
            // remove
            $trFile.remove();
          }
        },
        error: function(jqXHR, textStatus, errorThrown) {
          $(".ft-error-api-msg").text(jqXHR.responseJSON.message);
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

