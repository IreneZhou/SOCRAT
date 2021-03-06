'use strict'

BaseCtrl = require 'scripts/BaseClasses/BaseController.coffee'
require 'handsontable/dist/handsontable.full.css'
require 'imports?Handsontable=handsontable/dist/handsontable.full.js!ngHandsontable/dist/ngHandsontable.js'

module.exports = class GetDataMainCtrl extends BaseCtrl
  @inject '$scope',
    '$state',
    'app_analysis_getData_dataService',
    'app_analysis_getData_showState',
    'app_analysis_getData_jsonParser',
    'app_analysis_getData_dataAdaptor',
    'app_analysis_getData_inputCache',
    '$timeout'

  initialize: ->
    @d3 = require 'd3'
    # rename deps
    @dataManager = @app_analysis_getData_dataService
    @showStateService = @app_analysis_getData_showState
    @inputCache = @app_analysis_getData_inputCache
    @jsonParser = @app_analysis_getData_jsonParser
    @dataAdaptor = @app_analysis_getData_dataAdaptor

    # get initial settings
    @DATA_TYPES = @dataManager.getDataTypes()
    @dataType = ''
    @socrdataset = @socrDatasets[0]

    # init table
    @tableSettings =
      colHeaders: off
      rowHeaders: on
      stretchH: "all"
      contextMenu: on
      onAfterChange: (changes, source) =>
        data = @dataAdaptor.toDataFrame @tableData, @tableSettings.colHeaders
        @inputCache.setData data

    @tableData = [
      ['Copy', 'paste', 'your', 'data', 'here']
    ]

    try
      @stateService = @showStateService.create ['grid', 'socrData', 'worldBank', 'generate', 'jsonParse'], @
    catch e
      console.log e.message

    # adding listeners
    @$scope.$on 'update showStates', (obj, data) =>
      @stateService.set data
      console.log @showState
      # TODO: fix this workaround for displaying copy-paste table
      @dataType = @DATA_TYPES.FLAT if data is 'grid'

    @$scope.$on '$viewContentLoaded', ->
      console.log 'get data main div loaded'

  passReceivedData: (data) ->
    if data.dataType is @DATA_TYPES.NESTED
      @dataType = @DATA_TYPES.NESTED
      # save to db
      @inputCache.setData data
    else
      # default data type is 2d 'flat' table
      data.dataType = @DATA_TYPES.FLAT
      @dataType = @DATA_TYPES.FLAT

      # update table
      @$timeout =>
        @tableSettings.colHeaders = data.header
        console.log @tableSettings.colHeaders
        @tableData = data.data
        console.log 'ht updated'

  # available SOCR Datasets
  socrDatasets: [
    id: 'IRIS'
    name: 'Iris Flower Dataset'
  ,
    id: 'KNEE_PAIN'
    name: 'Simulated SOCR Knee Pain Centroid Location Data'
  ]

  getWB: ->
    # default value
    if @size is undefined
      @size = 100
    # default option
    if @option is undefined
      @option = '4.2_BASIC.EDU.SPENDING'

    url = 'http://api.worldbank.org/countries/indicators/' + @option +
        '?per_page=' + @size + '&date=2011:2011&format=jsonp' +
        '&prefix=JSON_CALLBACK'

    @jsonParser.parse
      url: url
      type: 'worldBank'
    .then(
      (data) =>
        console.log 'resolved'
        @passReceivedData data
      ,
      (msg) ->
        console.log 'rejected:' + msg
      )

  getSocrData: ->
    switch @socrdataset.id
      # TODO: host on SOCR server
      when 'IRIS' then url = 'https://www.googledrive.com/host//0BzJubeARG-hsMnFQLTB3eEx4aTQ'
      when 'KNEE_PAIN' then url = 'https://www.googledrive.com/host//0BzJubeARG-hsLUU1Ul9WekZRV0U'
      # default option
      else url = 'https://www.googledrive.com/host//0BzJubeARG-hsMnFQLTB3eEx4aTQ'

    @d3.text url,
      (dataResults) =>
        if dataResults?.length > 0
          # parse to unnamed array
          dataResults = @d3.csv.parseRows dataResults
          data = @dataAdaptor.toDataFrame dataResults
          @passReceivedData data
        else
          console.log 'rejected:' + msg

  getJsonByUrl: (type) ->
    @d3.json @jsonUrl,
      (dataResults) =>
        # check that data object is not empty
        if dataResults? and Object.keys(dataResults)?.length > 0
          res = @dataAdaptor.jsonToFlatTable dataResults
          # check if JSON contains "flat data" - 2d array
          if res
            _data = @dataAdaptor.toDataFrame res
          else
            _data =
              data: dataResults
              dataType: @DATA_TYPES.NESTED
          @passReceivedData _data
        else
          console.log 'GETDATA: request failed'
