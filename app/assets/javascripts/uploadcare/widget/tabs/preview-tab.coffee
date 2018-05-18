{
  utils,
  utils: {abilities: {URL}},
  ui: {progress},
  templates: {tpl},
  jQuery: $,
  crop: {CropWidget},
  locale: {t}
} = uploadcare

uploadcare.namespace 'widget.tabs', (ns) ->
  class ns.PreviewTab extends ns.BasePreviewTab

    constructor: ->
      super

      $.each @dialogApi.fileColl.get(), (i, file) =>
        @__setFile(file)

      @dialogApi.fileColl.onAdd.add(@__setFile)

      @widget = null
      @__state = null

    __setFile: (@file) =>
      ifCur = (fn) =>
        =>
          if file == @file
            fn.apply(null, arguments)

      tryToLoadImagePreview = utils.once(@__tryToLoadImagePreview)
      tryToLoadVideoPreview = utils.once(@__tryToLoadVideoPreview)

      @__setState('unknown', {})
      @file.progress ifCur (info) =>
        info = info.incompleteFileInfo
        label = (info.name || "") + utils.readableFileSize(info.size, '', ', ')
        @element('label').text(label)

        source = info.sourceInfo
        blob = utils.abilities.Blob
        if source.file and blob and source.file instanceof blob
          tryToLoadImagePreview(file, source.file)
          .fail =>
            tryToLoadVideoPreview(file, source.file)

      @file.done ifCur (info) =>
        if @__state == 'video'
          return

        if info.isImage
          # avoid subsequent image states
          if @__state != 'image'
            src = info.originalUrl
            # 1162x684 is 1.5 size of conteiner
            src += "-/preview/1162x693/-/setfill/efefef/-/format/jpeg/-/progressive/yes/"
            imgInfo = info.originalImageInfo
            @__setState('image', {src, name: info.name})
            @initImage([imgInfo.width, imgInfo.height], info.cdnUrlModifiers)
        else
          # , but update if other
          @__setState('regular', {file: info})

      @file.fail ifCur (error, info) =>
        @__setState('error', {error, file: info})

    __tryToLoadImagePreview: (file, blob) =>
      df = $.Deferred()

      if (
        file.state() != 'pending' or
        not blob.size or
        blob.size >= @settings.multipartMinSize
      )
        return df.reject().promise()


      utils.image.drawFileToCanvas(
        blob, 1550, 924, '#efefef', @settings.imagePreviewMaxSize
      )
      .done (canvas, size) =>
        utils.canvasToBlob canvas, 'image/jpeg', 0.95,
          (blob) =>
            df.resolve()

            canvas.width = canvas.height = 1
            if (
              file.state() != 'pending' or
              @dialogApi.state() != 'pending' or
              @file != file
            )
              return

            src = URL.createObjectURL(blob)
            @dialogApi.always ->
              URL.revokeObjectURL(src)

            if @__state != 'image'
              @__setState('image', {src, name: ""})
              @initImage(size)
      .fail(df.reject)

      df.promise()

    __tryToLoadVideoPreview: (file, blob) =>
      df = $.Deferred()

      if (
        not URL or
        not blob.size
      )
        return df.reject().promise()

      src = URL.createObjectURL(blob)
      op = utils.videoLoader(src)
      op
      .fail =>
        URL.revokeObjectURL(src)
        df.reject()
      .done =>
        df.resolve()

        @dialogApi.always ->
          URL.revokeObjectURL(src)

        @__setState('video')
        videoTag = @element('video')

        # hack to enable seeking due to bug in MediaRecorder API
        # https://bugs.chromium.org/p/chromium/issues/detail?id=569840
        videoTag.on('loadeddata', () ->
          el = videoTag.get(0)
          el.currentTime = 360000 # 100 hours
          videoTag.off('loadeddata')
        )
        videoTag.on('ended', () ->
          el = videoTag.get(0)
          el.currentTime = 0
          videoTag.off('ended')
        )
        # end of hack

        videoTag.attr('src', src)

      df.promise()

    element: (name) ->
      @container.find('.uploadcare-dialog-preview-' + name)

    # error
    # unknown
    # image
    # regular
    __setState: (state, data) ->
      @__state = state
      @container.empty().append(tpl("tab-preview-#{state}", data))

      if state is 'unknown' and @settings.crop
        @element('done').hide()

    initImage: (imgSize, cdnModifiers) ->
      img = @element('image')
      done = @element('done')

      imgLoader = utils.imageLoader(img[0])
        .done =>
          @element('root').addClass('uploadcare-dialog-preview--loaded')
        .fail =>
          @file = null
          @__setState('error', {error: 'loadImage'})

      startCrop = =>
        done.removeClass('uploadcare-disabled-el')

        @widget = new CropWidget(img, imgSize, @settings.crop[0])
        if cdnModifiers
          @widget.setSelectionFromModifiers(cdnModifiers)

        done.on 'click', =>
          newFile = @widget.applySelectionToFile(@file)
          @dialogApi.fileColl.replace(@file, newFile)
          true

      if @settings.crop
        @element('title').text(t('dialog.tabs.preview.crop.title'))
        done.addClass('uploadcare-disabled-el')
        done.text(t('dialog.tabs.preview.crop.done'))

        @populateCropSizes()

        imgLoader.done ->
          # Often IE 11 doesn't do reflow after image.onLoad
          # and actual image remains 28x30 (broken image placeholder).
          # Looks like defer always fixes it.
          utils.defer(startCrop)


    populateCropSizes: ->
      if @settings.crop.length <= 1
        return

      @element('root').addClass('uploadcare-dialog-preview--with-sizes')

      control = @element('crop-sizes')
      template = control.children()
      currentClass = 'uploadcare-crop-size--current'

      $.each @settings.crop, (i, crop) =>
        prefered = crop.preferedSize
        if prefered
          gcd = utils.gcd(prefered[0], prefered[1])
          caption = "#{prefered[0] / gcd}:#{prefered[1] / gcd}"
        else
          caption = t('dialog.tabs.preview.crop.free')

        item = template.clone().appendTo(control)
          .attr('data-caption', caption)
          .on 'click', (e) =>
            if @widget
              @widget.setCrop(crop)
              control.find('>*').removeClass(currentClass)
              item.addClass(currentClass)
        if prefered
          size = utils.fitSize(prefered, [40, 40], true)
          item.children()
            .css(
              width: Math.max(20, size[0])
              height: Math.max(12, size[1])
            )

      template.remove()
      control.find('>*').eq(0).addClass(currentClass)
