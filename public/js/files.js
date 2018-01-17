(function() {
  $(function() {

    var getInsertIdxNewDir = function(newDirname) {
      var insertIdx = 0;
      var idx = 0;
      $("tr.ft-table-row-file").each(function(index) {
        var dirname = $(this).data("filename");
        var isDirectory = $(this).data("is-directory");
        if (!isDirectory)
          return;

        if ( newDirname < dirname ) {
          return false;
        }
        else {
          ++insertIdx;
        }
        ++idx;
      });

      return insertIdx;
    };
    var insertNewDir = function(newDirname) {
      var urlFor  = $("body").data("url-for");
      var baseDir = $(".file-explorer").data("base-dir");
      var subUrl  = baseDir + "/" + newDirname;

      var source   = $("#ft-template-create-dir").html();
      var template = Handlebars.compile(source);
      var context = {
        api_url:  urlFor + "api/files/" + subUrl,
        sub_url:  urlFor + "files/" + subUrl,
        filename: newDirname
      };
      var html = template(context);

      var insertIdx = getInsertIdxNewDir(newDirname);
      var idx = 0;
      var $tr = $("tr.ft-table-row-file[data-is-directory=true]");
      var $elem;
      $tr.each(function(index) {
        $elem = $(this);

        var dirname = $(this).data("filename");
        var isDirectory = $(this).data("is-directory");
        if (!isDirectory)
          return;

        if ( idx === insertIdx ) {
          $(this).before(html)
          return false;
        }
        ++idx;
      });
      if ( idx === $tr.length )
        $elem.after(html);
    };

    $(document).on("click", ".ft-button-popup-create-dir", function (e) {
      var source   = $("#ft-template-modal").html();
      var template = Handlebars.compile(source);
      var apiUrl   = $(this).data("api-url");

      var bodyHtml
        = '<div class="ft-modal-data">'
        + '  <div class="form-group">'
        + "    <label>Enter the folder name to be created.</label>"
        + '    <input class="form-control ft-modal-dest-filename" placeholder="New folder" autofocus="autofocus">'
        + "  </div>"
        + "</div>"
        ;

      var context = {
        title:        "Create a new folder?",
        body:         bodyHtml,
        button_label: "Create",
        button_class: "ft-button-create-dir",
        api_url:      apiUrl
      };
      var html = template(context);

      $("#ft-modal-confirm").remove();
      $(".ft-modal").html(html);
      $("#ft-modal-confirm").modal("show");

      // FIXME : doesn't work now
      //$(".ft-modal-dest-filename").focus();
    });

    $(document).on("click", ".ft-button-popup-upload-file", function (e) {
      var source   = $("#ft-template-modal").html();
      var template = Handlebars.compile(source);
      var apiUrl   = $(this).data("api-url");

      var bodyHtml
        = '<div class="ft-modal-data">'
        + '  <div class="form-group">'
        + '    <label>File input</label>'
        + '    <input type="file">'
        + '  </div>'
        + "</div>"
        ;

      var context = {
        title:        "Upload a new file?",
        body:         bodyHtml,
        button_label: "Upload",
        button_class: "ft-button-upload-file",
        api_url:      apiUrl
      };
      var html = template(context);

      $("#ft-modal-confirm").remove();
      $(".ft-modal").html(html);
      $("#ft-modal-confirm").modal("show");

      // FIXME : doesn't work now
      //$(".ft-modal-dest-filename").focus();
    });

    $(document).on("click", ".ft-button-popup", function (e) {
      var action   = $(this).data("action");
      var $trFile  = $(this).closest("tr");
      var filename = $trFile.data("filename");
      var isDir    = $trFile.data("is-directory");
      var source   = $("#ft-template-modal").html();
      var template = Handlebars.compile(source);

      var fileType = "File";
      if ( isDir === true )
        fileType = "Directory";

      var context;
      var bodyHtml;
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

      // FIXME : doesn't work now
      // rename action must be separated later
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

    $(document).on("click", ".ft-button-create-dir", function (e) {
      var newDir = $(".ft-modal-dest-filename").val();
      var apiUrl = $(this).data("api-url");

      /**
       * request to delete file on server
       */
      $.ajax({
        url: apiUrl + "/" + newDir,
        type: "POST",
        success: function(result) {
          insertNewDir(result.destDirname);
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

