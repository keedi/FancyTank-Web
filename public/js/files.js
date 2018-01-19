(function() {
  $(function() {

    var getInsertIdxNew = function(newName, opt) {
      var idx = 0;
      $("tr.ft-table-row-file").each(function(index) {
        var name        = $(this).data("filename");
        var isDirectory = $(this).data("is-directory");

        if ( opt.type === "dir" ) {
          if (!isDirectory) {
            return false;
          }
        }
        else if ( opt.type === "file" ) {
          if (isDirectory) {
            ++idx;
            return;
          }
        }

        if ( newName < name ) {
          return false;
        }
        ++idx;
      });

      return idx;
    };

    var insertNew = function(newName, opt) {
      var urlFor  = $("body").data("url-for");
      var baseDir = $(".file-explorer").data("base-dir");
      var remainUrl  = baseDir + "/" + newName;

      var apiUrl;
      var subUrl;
      var downloadUrl;
      var source;
      if ( opt.type === "dir" ) {
        apiUrl = urlFor + "api/files/" + remainUrl;
        subUrl = urlFor + "files/" + remainUrl;
        source = $("#ft-template-create-dir").html();
      }
      else if ( opt.type === "file" ) {
        apiUrl      = urlFor + "api/files/" + remainUrl; // ???
        subUrl      = urlFor + "preview/" + remainUrl;
        downloadUrl = urlFor + "download/" + remainUrl;
        source      = $("#ft-template-upload-file").html();
      }

      var template = Handlebars.compile(source);
      var context = {
        api_url:      apiUrl,
        sub_url:      subUrl,
        download_url: downloadUrl,
        filename:     newName
      };
      var html = template(context);

      var insertIdx = getInsertIdxNew(newName, opt);
      var $tr = $("tr.ft-table-row-file");
      if ( insertIdx < $tr.length )
        $tr.eq(insertIdx).before(html);
      else
        $tr.eq(-1).after(html);

      /**
      var idx = 0;
      var $elem;
      $tr.each(function(index) {
        $elem = $(this);

        if ( idx === insertIdx ) {
          $(this).before(html)
          return false;
        }
        ++idx;
      });
      if ( idx === $tr.length )
        $elem.after(html);
      */
    };

    $(document).on("click", ".ft-button-popup-submenu", function (e) {
      var action   = $(this).data("action");
      var source   = $("#ft-template-modal").html();
      var template = Handlebars.compile(source);
      var apiUrl   = $(this).data("api-url");

      var context;
      var bodyHtml;
      if (action === "create-dir") {
        bodyHtml
          = '<div class="ft-modal-data">'
          + '  <div class="form-group">'
          + "    <label>Enter the folder name to be created.</label>"
          + '    <input class="form-control ft-modal-dest-filename" placeholder="New folder" autofocus="autofocus">'
          + "  </div>"
          + "</div>"
          ;

        context = {
          title:        "Create a new folder?",
          body:         bodyHtml,
          button_label: "Create",
          button_class: "ft-button-create-dir",
          api_url:      apiUrl
        };
      }
      else if (action === "upload-file") {
        bodyHtml
          = '<div class="ft-modal-data">'
          + '  <div class="form-group">'
          + '    <label>File input</label>'
          + '    <input type="file" name="upload_file">'
          + '  </div>'
          + '</div>'
          ;

        context = {
          title:        "Upload a new file?",
          body:         bodyHtml,
          button_label: "Upload",
          button_class: "ft-button-upload-file",
          api_url:      apiUrl
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
       * request to rename file on server
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
       * check request new directory is valid or not
       */
      if ( newDir.match(/[\\/:?*"|]/) ) {
        $(".ft-error-api-msg").text('Following characters are not allowed: \\ / : ? * " |');
        $(".ft-error-api").show(400, function() {
          setTimeout(function() {
            $(".ft-error-api").fadeOut(600);
          }, 3000);
        });
        $('#ft-modal-confirm').modal('hide');
        return;
      }

      /**
       * request to create dir on server
       */
      $.ajax({
        url: apiUrl + "/" + newDir,
        type: "POST",
        success: function(result) {
          insertNew( result.destDirname, { type: "dir" } );
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

    $(document).on("click", ".ft-button-upload-file", function (e) {
      var basename = $(".ft-modal-data input[type=file]").val().replace(/.*(\/|\\)/, '');
      var apiUrl   = $(this).data("api-url");

      // https://developer.mozilla.org/en-US/docs/Learn/HTML/Forms/Sending_forms_through_JavaScript
      // https://developer.mozilla.org/en-US/docs/Web/API/FormData/Using_FormData_Objects
      // https://stackoverflow.com/a/8244082
      // https://coderwall.com/p/p-n7eq/file-uploads-with-jquery-html5-and-formdata
      var formData = new FormData();
      formData.append( "upload_file", $("input[type=file]")[0].files[0] );

      /**
       * request to upload a file on server
       * https://stackoverflow.com/a/25983643
       */
      $.ajax({
        url: apiUrl + "/" + basename,
        type: "POST",
        data: formData,
        processData: false,
        contentType: false,
        success: function(result) {
          insertNew( result.destFilename, { type: "file" } );
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

