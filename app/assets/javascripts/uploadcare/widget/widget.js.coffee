# = require ../files
# = require ./dragdrop
# = require ./template
# = require ./dialog

uploadcare.whenReady ->
  {
    namespace,
    utils,
    uploads,
    files,
    jQuery: $
  } = uploadcare

  {t} = uploadcare.locale

  namespace 'uploadcare.widget', (ns) ->
    class ns.Widget

      constructor: (element) ->
        @element = $(element)
        @settings = utils.buildSettings @element.data()
        @__onChange = $.Callbacks()

        @__setupWidget()
        @currentFile = null
        @template.reset()

        @element.on 'change.uploadcare', => @reloadInfo()
        @reloadInfo()

      __reset: (keepValue=false) =>
        @currentFile?.upload?.reject()
        @currentFile = null
        @template.reset()
        @value('') unless keepValue

      __setFile: (newFile, keepValue=false) =>
        if newFile == @currentFile
          if newFile
            @__updateValue() unless keepValue
          return
        @__reset(keepValue)
        if newFile
          @currentFile = newFile
          @template.started()
          @currentFile.startUpload()
          @template.listen @currentFile.upload
          @currentFile.info()
            .fail (error, file) =>
              if file == @currentFile
                @__fail error
            .done (file) =>
              if file == @currentFile
                @template.setFileInfo(file)
                @template.loaded()
          @__updateValue() unless keepValue

      __updateValue: ->
        @currentFile.info().done (file) =>
          if file == @currentFile
            if file.cdnUrlModifiers
              @value(file.cdnUrl)
            else
              @value(file.fileId)

      value: (value) ->
        if value?
          if @element.val() != value
            @element.val(value)
            @__onChange.fire(value)
          this
        else
          @element.val()

      reloadInfo: =>
        if @element.val()
          file = uploadcare.fileFrom @settings, 'uploaded', @element.val()
          @__setFile file, true
        else
          @__reset()
        this

      __fail: (error) =>
        @__reset()
        @template.error error

      __setupWidget: ->
        @template = new ns.Template(@settings, @element)

        @template.addButton('cancel', t('buttons.cancel')).on('click', => @__reset())
        @template.addButton('remove', t('buttons.remove')).on('click', => @__reset())

        # Create the dialog and widget buttons
        if @settings.tabs.length > 0
          if 'file' in @settings.tabs
            fileButton = @template.addButton('file')
            fileButton.on 'click', =>
              @openDialog('file')

          dialogButton = @template.addButton('dialog')
          dialogButton.on 'click', => @openDialog()


        # Enable drag and drop
        ns.dragdrop.receiveDrop(@__openDialogWithFile, @template.dropArea)
        @template.dropArea.on 'dragstatechange.uploadcare', (e, active) =>
          unless active && uploadcare.isDialogOpened()
            @template.dropArea.toggleClass('uploadcare-dragging', active)

        @template.content.on 'click', '@uploadcare-widget-file-name', =>
          @openDialog()

      __openDialogWithFile: (type, data) =>
        file = uploadcare.fileFrom @settings, type, data
        uploadcare.openDialog(@settings, file).done(@__setFile)

      openDialog: (tab) ->
        uploadcare.openDialog(@settings, @currentFile, tab)
          .done(@__setFile)
          .fail (file) =>
            unless file == @currentFile
              @__setFile null

      api: ->
        @onChange ||= utils.bindAll @__onChange, [
          'add'
          'empty'
          'has'
          'remove'
        ]
        @__api ||= utils.bindAll this, [
          'onChange'
          'openDialog'
          'reloadInfo'
          'value'
        ]
