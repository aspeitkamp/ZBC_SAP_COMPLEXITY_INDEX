*&---------------------------------------------------------------------*
*& Report ZBC_SAP_COMPLEXITY_INDEX
*&---------------------------------------------------------------------*
*& Calculation of a "SAP Complexity Index"
*&
*&   The purpose of the report is to calculate a comparable metric
*&   of system complexity. It uses a defined set of tables from all
*&   areas (modules) of a SAP system.
*&
*&   By evaluating the system in regular intervals it is possible
*&   to identify areas with high growth in complexity or to identify
*&   areas with potential for improvements.
*&
*&   The result can be:
*&    - viewed via SALV
*&    - exported as an Excel XLSX
*&    - mailed as Excel XLSX file attachment (e.g. in a monthly job run)
*&
*&   The report is inspired by the paper
*&   "Measuring Complexity of SAP Systems" by Ilja Holub and Tomas Bruckner
*&
*&---------------------------------------------------------------------*
*&  Created: Arno Speitkamp, ASP-data GmbH
*&---------------------------------------------------------------------*
REPORT zbc_sap_complexity_index.

TABLES:
  dd02l.

TYPES:
  BEGIN OF ts_result,
    module     TYPE string,
    ps_posid   TYPE string,
    component  TYPE df14t-name,
    ddtext     TYPE string,
    tabname    TYPE dd02l-tabname,
    clidep     TYPE dd02l-clidep,
    complexity TYPE i,
  END OF ts_result,

  tt_result TYPE STANDARD TABLE OF ts_result.

DATA:
  gr_salv      TYPE REF TO cl_salv_table  ##NEEDED,
  gt_result    TYPE tt_result             ##NEEDED,
  gt_xlsx_data TYPE solix_tab             ##NEEDED,
  gv_xlsx_size TYPE i                     ##NEEDED.

CONSTANTS:
  cv_file_name  TYPE string     VALUE 'SAP_Complexity_Index.xlsx' ##NO_TEXT,
  cv_mail_title TYPE so_obj_des VALUE 'SAP Complexity Report'     ##NO_TEXT.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-010.
SELECT-OPTIONS:
  s_mandt FOR sy-mandt DEFAULT '300',
  s_table FOR dd02l-tabname.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-011.
PARAMETERS:
  rb_show TYPE sap_bool RADIOBUTTON GROUP rb1 DEFAULT 'X' USER-COMMAND rb,
  rb_mail TYPE sap_bool RADIOBUTTON GROUP rb1,
  rb_down TYPE sap_bool RADIOBUTTON GROUP rb1,
  p_smtp  TYPE ad_smtpadr MODIF ID mm,
  p_path  TYPE string MODIF ID md.
SELECTION-SCREEN END OF BLOCK b2.


*----------------------------------------------------------------------*
INITIALIZATION.
*----------------------------------------------------------------------*
  " default evaluation
  s_table[] = VALUE #( ( sign = 'I'  option = 'EQ'  low = 'T880' )
                       ( sign = 'I'  option = 'EQ'  low = 'T014' )
                       ( sign = 'I'  option = 'EQ'  low = 'T001' )
                       ( sign = 'I'  option = 'EQ'  low = 'TGSB' )
                       ( sign = 'I'  option = 'EQ'  low = 'TFKB' )
                       ( sign = 'I'  option = 'EQ'  low = 'FM01' )
                       ( sign = 'I'  option = 'EQ'  low = 'T003' )

                       " Controlling
                       ( sign = 'I'  option = 'EQ'  low = 'TKA01' )
                       ( sign = 'I'  option = 'EQ'  low = 'TKEB' )

                       " Logistics General
                       ( sign = 'I'  option = 'EQ'  low = 'T025' )
                       ( sign = 'I'  option = 'EQ'  low = 'T001W' )
                       ( sign = 'I'  option = 'EQ'  low = 'T499S' )
                       ( sign = 'I'  option = 'EQ'  low = 'TSPA' )

                       " Sales & Distribution
                       ( sign = 'I'  option = 'EQ'  low = 'TVKO' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVTW' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVBUR' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVKGR' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVAK' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVPT' )

                       " Materials Managment
                       ( sign = 'I'  option = 'EQ'  low = 'T001L' )
                       ( sign = 'I'  option = 'EQ'  low = 'T024E' )
                       ( sign = 'I'  option = 'EQ'  low = 'T024' )
                       ( sign = 'I'  option = 'EQ'  low = 'T161' )

                       " Logistics Execution
                       ( sign = 'I'  option = 'EQ'  low = 'T300' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVST' )
                       ( sign = 'I'  option = 'EQ'  low = 'TVLA' )
                       ( sign = 'I'  option = 'EQ'  low = 'TTDS' )

                       " Plant Maintenance
                       ( sign = 'I'  option = 'EQ'  low = 'T001W' )

                       " HR
                       ( sign = 'I'  option = 'EQ'  low = 'T500P' )
                       ( sign = 'I'  option = 'EQ'  low = 'T001P' )
                       ( sign = 'I'  option = 'EQ'  low = 'T501' )
                       ( sign = 'I'  option = 'EQ'  low = 'T503K' )

                       " Master Data
                       ( sign = 'I'  option = 'EQ'  low = 'T685' )
                       ( sign = 'I'  option = 'EQ'  low = 'AGR_DEFINE' )

                       " Custom Code
                       ( sign = 'I'  option = 'EQ'  low = 'DD02L' )
                       ( sign = 'I'  option = 'EQ'  low = 'TADIR' )
                       ( sign = 'I'  option = 'EQ'  low = 'TSTC' )
  ).

  " download path is the SAP work directory
  PERFORM get_default_path CHANGING p_path.
  PERFORM get_default_smtp CHANGING p_smtp.


*----------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
*----------------------------------------------------------------------*
  LOOP AT SCREEN.
    CASE abap_true.
      WHEN rb_show.
        " deactivate download path
        IF screen-group1 = 'MM' OR
           screen-group1 = 'MD'.
          screen-input     = 0.
          screen-active    = 0.
          screen-invisible = 1.
          MODIFY SCREEN.
        ENDIF.
      WHEN rb_mail.
        " deactivate download path
        IF screen-group1 = 'MD'.
          screen-input     = 0.
          screen-active    = 0.
          screen-invisible = 1.
          MODIFY SCREEN.
        ENDIF.
      WHEN rb_down.
        " deactivate mail address
        IF screen-group1 = 'MM'.
          screen-input     = 0.
          screen-active    = 0.
          screen-invisible = 1.
          MODIFY SCREEN.
        ENDIF.
    ENDCASE.
  ENDLOOP.





*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*
  " mandatory fields are supplied?
  CASE abap_true.
    WHEN rb_mail.
      IF p_smtp IS INITIAL.
        MESSAGE s206(HRPBSSA) DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.

    WHEN rb_down.
      IF p_path IS INITIAL.
        MESSAGE s011(/UI5/UI5_REP) DISPLAY LIKE 'E'.
      ENDIF.
  ENDCASE.


  PERFORM calculate_complexity_index USING    s_mandt[]
                                              s_table[]
                                     CHANGING gt_result.

  " always prepare the SALV as we use the formatting for the XLSX as well
  PERFORM show_salv USING    rb_show
                    CHANGING gt_result
                             gr_salv.

  " email and download requires further preparation
  CASE abap_true.
    WHEN rb_mail.
      PERFORM convert_itab_to_xlsx USING    gt_result
                                            gr_salv
                                   CHANGING gt_xlsx_data
                                            gv_xlsx_size.

      PERFORM send_mail USING p_smtp
                              gt_xlsx_data
                              gv_xlsx_size.

    WHEN rb_down.
      PERFORM convert_itab_to_xlsx USING    gt_result
                                            gr_salv
                                   CHANGING gt_xlsx_data
                                            gv_xlsx_size.

      PERFORM download USING    p_path
                                gv_xlsx_size
                       CHANGING gt_xlsx_data.
  ENDCASE.


FORM get_default_smtp CHANGING cv_smtp TYPE ad_smtpadr.

  DATA:
    ls_smtp   TYPE bapiadsmtp,
    lt_return TYPE STANDARD TABLE OF bapiret2,
    lt_smtp   TYPE STANDARD TABLE OF bapiadsmtp.

  CHECK cv_smtp IS INITIAL.

  CALL FUNCTION 'BAPI_USER_GET_DETAIL'
    EXPORTING
      username       = sy-uname
    TABLES
      return         = lt_return
      addsmtp        = lt_smtp.

  READ TABLE lt_smtp INTO ls_smtp WITH KEY std_no = abap_true TRANSPORTING e_mail.

  IF sy-subrc = 0.
    cv_smtp = ls_smtp-e_mail.
  ENDIF.

ENDFORM.


FORM get_default_path CHANGING cv_path TYPE string.

  DATA:
    lv_file_sep(1) TYPE c.

  CHECK cv_path IS INITIAL.

  cl_gui_frontend_services=>get_sapgui_workdir(
    CHANGING
      sapworkdir            = cv_path
    EXCEPTIONS
      get_sapworkdir_failed = 1                " Registry Error
      cntl_error            = 2                " Control error
      error_no_gui          = 3                " No GUI available
      not_supported_by_gui  = 4                " GUI does not support this
      OTHERS                = 5 ).

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  cl_gui_frontend_services=>get_file_separator(
    CHANGING
      file_separator       = lv_file_sep
    EXCEPTIONS
      not_supported_by_gui = 1
      error_no_gui         = 2
      cntl_error           = 3
      OTHERS               = 4 ).

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

  cv_path = cv_path && lv_file_sep.

ENDFORM.


FORM convert_itab_to_xlsx USING    it_result    TYPE tt_result
                                   io_salv      TYPE REF TO cl_salv_table
                          CHANGING ct_xlsx_data TYPE solix_tab
                                   cv_xlsx_size TYPE i.

  DATA:
    lr_excel  TYPE REF TO zcl_excel,
    lr_writer TYPE REF TO zif_excel_writer,
    lv_msg    TYPE string.

  CLEAR:
    ct_xlsx_data,
    cv_xlsx_size.

  CHECK it_result IS NOT INITIAL.

  CREATE OBJECT lr_excel.

  TRY.
      DATA(lr_worksheet) = lr_excel->get_active_worksheet( ).
      lr_worksheet->set_title( 'SAP_Complexity_Report' ).

      lr_worksheet->bind_alv( EXPORTING
                                io_alv      = io_salv
                                it_table    = it_result ).

      lr_worksheet->calculate_column_widths( ).

      CREATE OBJECT lr_writer TYPE zcl_excel_writer_2007.
      DATA(lv_xstring) = lr_writer->write_file( io_excel = lr_excel ).

    CATCH zcx_excel INTO DATA(lcx_excel).
      lv_msg = lcx_excel->get_text( ).
      MESSAGE lv_msg TYPE 'E'.
  ENDTRY.

  ct_xlsx_data = cl_bcs_convert=>xstring_to_solix( iv_xstring  = lv_xstring ).
  cv_xlsx_size = xstrlen( lv_xstring ).

ENDFORM.


FORM send_mail USING iv_smtp      TYPE ad_smtpadr
                     it_xlsx_data TYPE solix_tab
                     iv_xlsx_size TYPE i.

  DATA:
    lv_msg                TYPE string,
    lv_sent               TYPE abap_bool,
    lv_sood_bytecount     TYPE sood-objlen,
    t_mailtext            TYPE soli_tab,         " FIXME: SO10 Text
    lt_attachment_header  TYPE soli_tab,
    ls_attachment_header  TYPE soli,
    lv_attachment_subject TYPE sood-objdes.


  CHECK NOT iv_smtp      IS INITIAL AND
        NOT it_xlsx_data IS INITIAL AND
        NOT iv_xlsx_size IS INITIAL.

  " FIXME: Validate Email Address
  TRY.
      DATA(lr_send_request) = cl_bcs=>create_persistent( ).

      t_mailtext = VALUE soli_tab( ( line = |Analysis date: | && |{ sy-datum DATE = User }|  ) ).

      DATA(lr_document) = cl_document_bcs=>create_document( i_type    = 'RAW' "#EC NOTEXT
                                                            i_text    = t_mailtext
                                                            i_subject = cv_mail_title ).
*     " Add attachment to document
      " ( since the new excelfiles have an 4-character extension .xlsx but the attachment-type only holds 3 charactes .xls,
      "   we have to specify the real filename via attachment header
      "   Use attachment_type xls to have SAP display attachment with the excel-icon )
      lv_attachment_subject  = cv_file_name.
      CONCATENATE '&SO_FILENAME=' lv_attachment_subject INTO ls_attachment_header.
      APPEND ls_attachment_header TO lt_attachment_header.

      " Attachment
      lv_sood_bytecount = iv_xlsx_size.  " next method expects sood_bytecount instead of any positive integer *sigh*
      lr_document->add_attachment(  i_attachment_type    = 'XLS' "#EC NOTEXT
                                    i_attachment_subject = lv_attachment_subject
                                    i_attachment_size    = lv_sood_bytecount
                                    i_att_content_hex    = it_xlsx_data
                                    i_attachment_header  = lt_attachment_header ).

      " add document to send request
      lr_send_request->set_document( lr_document ).

      " add recipient(s) - here only 1 will be needed
      DATA(lr_recipient) = cl_cam_address_bcs=>create_internet_address( iv_smtp ).
      lr_send_request->add_recipient( lr_recipient ).

      " put mail into SOST, sending will be done by SOST job
      lv_sent = lr_send_request->send( i_with_error_screen = 'X' ).

      COMMIT WORK.

      IF lv_sent = abap_true.
        MESSAGE s805(zabap2xlsx).
      ELSE.
        MESSAGE e804(zabap2xlsx) WITH iv_smtp.
      ENDIF.

    CATCH cx_bcs INTO DATA(lcx_bcs).
      lv_msg = lcx_bcs->if_message~get_text( ).
      MESSAGE lv_msg TYPE 'E'.
  ENDTRY.

ENDFORM.


FORM show_salv USING    iv_rb_show TYPE sap_bool
               CHANGING ct_result  TYPE tt_result
                        cr_salv    TYPE REF TO cl_salv_table.

  DATA:
    lr_column TYPE REF TO cl_salv_column,
    lv_msg    TYPE string.

  " init
  CLEAR: cr_salv.

* show results
  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = cr_salv CHANGING t_table = ct_result ).

    CATCH cx_salv_msg INTO DATA(lcx_salv_msg).
      lv_msg = lcx_salv_msg->get_text( ).
      MESSAGE lv_msg TYPE 'I'.
      RETURN.
  ENDTRY.

  " set zebra and title
  DATA(lr_display_settings) = cr_salv->get_display_settings( ).
  lr_display_settings->set_striped_pattern( value = abap_true ).
  lr_display_settings->set_list_header( CONV #( 'SAP Detailed Complexity Report'(001) ) ).

  DATA(lr_columns) = cr_salv->get_columns( ).
  lr_columns->set_optimize( abap_true ).

  TRY.
      CLEAR: lr_column.
      lr_column = lr_columns->get_column( columnname = 'COMPLEXITY' ).

      IF lr_column IS BOUND.
        lr_column->set_short_text( 'Complexity'(002) ).
        lr_column->set_medium_text( 'Complexity'(002) ).
        lr_column->set_long_text( 'Complexity'(002) ).
      ENDIF.

      CLEAR: lr_column.
      lr_column = lr_columns->get_column( columnname = 'PS_POSID' ).

      IF lr_column IS BOUND.
        SELECT SINGLE scrtext_s, scrtext_m, scrtext_l FROM dd04t INTO @DATA(ls_ps_posid_txt)
          WHERE rollname = 'PS_POSID'
            AND ddlanguage = @sy-langu
            AND as4local   = 'A'
            AND as4vers    = ''.

        lr_column->set_short_text( ls_ps_posid_txt-scrtext_s ).
        lr_column->set_medium_text( ls_ps_posid_txt-scrtext_m ).
        lr_column->set_long_text( ls_ps_posid_txt-scrtext_l ).
      ENDIF.

      CLEAR: lr_column.
      lr_column = lr_columns->get_column( columnname = 'MODULE' ).

      IF lr_column IS BOUND.
        lr_column->set_short_text( 'Area'(003) ).
        lr_column->set_medium_text( 'Area'(003) ).
        lr_column->set_long_text( 'Area'(003) ).
      ENDIF.

    CATCH cx_salv_not_found INTO DATA(lcx_col_salv_not_found).
      lv_msg = lcx_col_salv_not_found->get_text( ).
      MESSAGE lv_msg TYPE 'I'.
  ENDTRY.

  " sort by MAIN area
  TRY.
      DATA(lr_sorts) = cr_salv->get_sorts( ).
      lr_sorts->add_sort( EXPORTING columnname = 'MODULE' ).

    CATCH cx_salv_not_found INTO DATA(lcx_sort_salv_not_found).
      lv_msg = lcx_sort_salv_not_found->get_text( ).
      MESSAGE lv_msg TYPE 'I'.

    CATCH cx_salv_existing INTO DATA(lcx_sort_salv_existing).
      lv_msg = lcx_sort_salv_existing->get_text( ).
      MESSAGE lv_msg TYPE 'I'.

    CATCH cx_salv_data_error INTO DATA(lcx_sort_salv_data_error).
      lv_msg = lcx_sort_salv_data_error->get_text( ).
      MESSAGE lv_msg TYPE 'I'.
  ENDTRY.

  TRY.
      DATA(lr_aggregations) = cr_salv->get_aggregations( ).
      lr_aggregations->add_aggregation( EXPORTING columnname  = 'COMPLEXITY' ).                            " ALV Control: Field Name of Internal Table Field

    CATCH cx_salv_data_error INTO DATA(lcx_aggr_cx_salv_data_error).
      lv_msg = lcx_aggr_cx_salv_data_error->get_text( ).
      MESSAGE lv_msg TYPE 'I'.
    CATCH cx_salv_not_found INTO DATA(lcx_aggr_salv_not_found).
      lv_msg = lcx_aggr_salv_not_found->get_text( ).
      MESSAGE lv_msg TYPE 'I'.
    CATCH cx_salv_existing INTO DATA(lcx_aggr_salv_existing).
      lv_msg = lcx_aggr_salv_existing->get_text( ).
      MESSAGE lv_msg TYPE 'I'.
  ENDTRY.

  " only show the SALV if this has been requested
  IF iv_rb_show = abap_true.
    cr_salv->get_functions( )->set_all( if_salv_c_bool_sap=>true ).
    cr_salv->display( ).
  ELSE.
    " reset the internal SALV mode in order to bind to the ALV during download
    " without actually displaying the SALV (or else we get a dump)
    cl_salv_bs_runtime_info=>set( EXPORTING
                                   display        = abap_false
                                   metadata       = abap_false
                                   data           = abap_true ).
  ENDIF.

ENDFORM.


FORM download USING    iv_file_path TYPE string
                       iv_xlsx_size TYPE i
              CHANGING ct_xlsx_data TYPE solix_tab.

  DATA:
    lv_complete_filename TYPE string.

  CHECK iv_xlsx_size IS NOT INITIAL AND
        ct_xlsx_data IS NOT INITIAL.

  lv_complete_filename = iv_file_path && cv_file_name.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize              = iv_xlsx_size
      filename                  = lv_complete_filename
      filetype                  = 'BIN'                " File type (ASCII, binary ...)
    CHANGING
      data_tab                  = ct_xlsx_data
    EXCEPTIONS
      file_write_error          = 1                    " Cannot write to file
      no_batch                  = 2                    " Cannot execute front-end function in background
      gui_refuse_filetransfer   = 3                    " Incorrect Front End
      invalid_type              = 4                    " Invalid value for parameter FILETYPE
      no_authority              = 5                    " No Download Authorization
      unknown_error             = 6                    " Unknown error
      header_not_allowed        = 7                    " Invalid header
      separator_not_allowed     = 8                    " Invalid separator
      filesize_not_allowed      = 9                    " Invalid file size
      header_too_long           = 10                   " Header information currently restricted to 1023 bytes
      dp_error_create           = 11                   " Cannot create DataProvider
      dp_error_send             = 12                   " Error Sending Data with DataProvider
      dp_error_write            = 13                   " Error Writing Data with DataProvider
      unknown_dp_error          = 14                   " Error when calling data provider
      access_denied             = 15                   " Access to File Denied
      dp_out_of_memory          = 16                   " Not enough memory in data provider
      disk_full                 = 17                   " Storage medium is full.
      dp_timeout                = 18                   " Data provider timeout
      file_not_found            = 19                   " Could not find file
      dataprovider_exception    = 20                   " General Exception Error in DataProvider
      control_flush_error       = 21                   " Error in Control Framework
      not_supported_by_gui      = 22                   " GUI does not support this
      error_no_gui              = 23                   " GUI not available
      OTHERS                    = 24
  ).

  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.


FORM calculate_complexity_index USING    it_range_mandt LIKE s_mandt[]
                                         it_range_table LIKE s_table[]
                                CHANGING ct_result      TYPE tt_result.

  DATA:
    ls_result           TYPE ts_result,
    lt_components       TYPE STANDARD TABLE OF fieldname,
    lv_component        TYPE fieldname.


  CLEAR: ct_result.

* Clients
  SELECT mandt FROM t000 INTO TABLE @DATA(lt_t000)
    WHERE mandt IN @it_range_mandt.

  IF sy-subrc <> 0.
    MESSAGE s820(01).       " client does not exist
    RETURN.
  ENDIF.

  " Table information
  SELECT dd02l~tabname,
         dd02l~clidep,
         dd02t~ddtext
   INTO CORRESPONDING FIELDS OF TABLE @ct_result
    FROM dd02l
    LEFT OUTER JOIN dd02t
    ON dd02t~tabname     = dd02l~tabname
    AND dd02t~ddlanguage = @sy-langu
    AND dd02t~as4local   = 'A'
    AND dd02t~as4vers    = '0000'
    WHERE dd02l~tabname IN @it_range_table
      AND dd02l~tabclass = 'TRANSP'
      AND dd02l~contflag IN ( 'C', 'G', 'W', 'E' ) ##TOO_MANY_ITAB_FIELDS.      " W für TSTC usw., 'E' = AGR_DEFINE

  IF sy-subrc <> 0.
    MESSAGE s002(wusl).   " no values found
    RETURN.
  ENDIF.

  LOOP AT lt_t000 ASSIGNING FIELD-SYMBOL(<ls_t000>).
    LOOP AT ct_result ASSIGNING FIELD-SYMBOL(<ls_result>).
      " add component
      SELECT df14t~name, df14l~ps_posid INTO ( @<ls_result>-component, @<ls_result>-ps_posid )
        UP TO 1 ROWS
        FROM tadir INNER JOIN tdevc ON
        tdevc~devclass = tadir~devclass
        INNER JOIN df14l
         ON df14l~fctr_id  = tdevc~component
        AND df14l~as4local = 'A'
        INNER JOIN df14t
         ON df14t~langu    = @sy-langu
        AND df14t~fctr_id  = tdevc~component
        AND df14t~as4local = 'A'
        WHERE tadir~pgmid = 'R3TR'
          AND tadir~object = 'TABL'
          AND tadir~obj_name = @<ls_result>-tabname.
      ENDSELECT.

      CASE <ls_result>-tabname.
        WHEN 'T001'.
          " will be evaluated by company code and later by country
          SELECT COUNT(*) FROM (<ls_result>-tabname) CLIENT SPECIFIED INTO <ls_result>-complexity
            WHERE mandt = <ls_t000>-mandt.

        WHEN 'TADIR'.
          SELECT COUNT(*) FROM (<ls_result>-tabname) INTO <ls_result>-complexity
            WHERE object = 'FORM'
              AND ( obj_name LIKE 'Y%' OR obj_name LIKE 'Z%' ).

          <ls_result>-ddtext = <ls_result>-ddtext && | | && '(OBJECT=FORM + OBJNAME starts with Y* or Z*)'(004).

        WHEN 'TSTC'.
          SELECT COUNT(*) FROM (<ls_result>-tabname) INTO <ls_result>-complexity
            WHERE tcode LIKE 'Y%' OR tcode LIKE 'Z%'.

          <ls_result>-ddtext = <ls_result>-ddtext && | | && '(TCODE starts with Y* or Z*)'(005).

        WHEN 'DD02L'.
          SELECT COUNT(*) FROM (<ls_result>-tabname) INTO <ls_result>-complexity
            WHERE ( tabname LIKE 'Y%' OR tabname LIKE 'Z%' ).

          <ls_result>-complexity = <ls_result>-complexity / 10.
          <ls_result>-ddtext = <ls_result>-ddtext && | | && '(TBNAME starts with Y* or Z*)'(006).

        WHEN 'T685'.
          SELECT COUNT(*) FROM (<ls_result>-tabname) CLIENT SPECIFIED INTO <ls_result>-complexity
            WHERE mandt = <ls_t000>-mandt.

          <ls_result>-complexity = <ls_result>-complexity / 10.
          <ls_result>-ddtext = <ls_result>-ddtext && | | && '(no. entries /'(007) && | 10)|.

        WHEN 'AGR_DEFINE'.
          SELECT COUNT(*) FROM (<ls_result>-tabname) CLIENT SPECIFIED INTO <ls_result>-complexity
            WHERE mandt = <ls_t000>-mandt.

          <ls_result>-complexity = <ls_result>-complexity / 100.
          <ls_result>-ddtext = <ls_result>-ddtext && | | && '(no. entries /'(007) && | 100)|.

        WHEN OTHERS.
          CASE <ls_result>-clidep.
            WHEN abap_true.
              SELECT COUNT(*) FROM (<ls_result>-tabname) CLIENT SPECIFIED INTO <ls_result>-complexity
                WHERE mandt = <ls_t000>-mandt.

            WHEN abap_false.
              SELECT COUNT(*) FROM (<ls_result>-tabname) INTO <ls_result>-complexity.
          ENDCASE.
      ENDCASE.

      " determine main module (first part of the component description)
      CLEAR: lt_components.
      SPLIT <ls_result>-ps_posid AT '-' INTO TABLE lt_components.

      IF sy-subrc = 0.
        CLEAR: lv_component.
        READ TABLE lt_components INTO lv_component INDEX 1.
        <ls_result>-module = lv_component.
      ENDIF.

    ENDLOOP.

    " T001 will be added twice
    " (the second time with distinct countries)
    READ TABLE ct_result INTO ls_result WITH KEY tabname = 'T001'.

    IF sy-subrc = 0.
      SELECT COUNT( DISTINCT ( land1 ) ) FROM (ls_result-tabname) CLIENT SPECIFIED INTO @ls_result-complexity
        WHERE mandt = @<ls_t000>-mandt.

      ls_result-ddtext =  ls_result-ddtext && |DISTINCT Countries|.
      APPEND ls_result TO ct_result.
    ENDIF.

  ENDLOOP.

** show results
*  TRY.
*      cl_salv_table=>factory( IMPORTING r_salv_table = cr_salv CHANGING t_table = ct_result ).
*
*    CATCH cx_salv_msg INTO DATA(lcx_salv_msg).
*      lv_msg = lcx_salv_msg->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*      RETURN.
*  ENDTRY.
*
*  " set zebra and title
*  DATA(lr_display_settings) = cr_salv->get_display_settings( ).
*  lr_display_settings->set_striped_pattern( value = abap_true ).
*  lr_display_settings->set_list_header( CONV #( 'SAP Detailed Complexity Report'(001) ) ).
*
*  DATA(lr_columns) = cr_salv->get_columns( ).
*  lr_columns->set_optimize( abap_true ).
*
*  TRY.
*      CLEAR: lr_column.
*      lr_column = lr_columns->get_column( columnname = 'COMPLEXITY' ).
*
*      IF lr_column IS BOUND.
*        lr_column->set_short_text( 'Complexity'(002) ).
*        lr_column->set_medium_text( 'Complexity'(002) ).
*        lr_column->set_long_text( 'Complexity'(002) ).
*      ENDIF.
*
*      CLEAR: lr_column.
*      lr_column = lr_columns->get_column( columnname = 'PS_POSID' ).
*
*      IF lr_column IS BOUND.
*        SELECT SINGLE scrtext_s, scrtext_m, scrtext_l FROM dd04t INTO @DATA(ls_ps_posid_txt)
*          WHERE rollname = 'PS_POSID'
*            AND ddlanguage = @sy-langu
*            AND as4local   = 'A'.
*
*        lr_column->set_short_text( ls_ps_posid_txt-scrtext_s ).
*        lr_column->set_medium_text( ls_ps_posid_txt-scrtext_m ).
*        lr_column->set_long_text( ls_ps_posid_txt-scrtext_l ).
*      ENDIF.
*
*      CLEAR: lr_column.
*      lr_column = lr_columns->get_column( columnname = 'MODULE' ).
*
*      IF lr_column IS BOUND.
*        lr_column->set_short_text( 'Area'(003) ).
*        lr_column->set_medium_text( 'Area'(003) ).
*        lr_column->set_long_text( 'Area'(003) ).
*      ENDIF.
*
*    CATCH cx_salv_not_found INTO DATA(lcx_col_salv_not_found).
*      lv_msg = lcx_col_salv_not_found->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*  ENDTRY.
*
*  " sort by MAIN area
*  TRY.
*      DATA(lr_sorts) = cr_salv->get_sorts( ).
*      lr_sorts->add_sort( EXPORTING columnname = 'MODULE' ).
*
*    CATCH cx_salv_not_found INTO DATA(lcx_sort_salv_not_found).
*      lv_msg = lcx_sort_salv_not_found->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*
*    CATCH cx_salv_existing INTO DATA(lcx_sort_salv_existing).
*      lv_msg = lcx_sort_salv_existing->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*
*    CATCH cx_salv_data_error INTO DATA(lcx_sort_salv_data_error).
*      lv_msg = lcx_sort_salv_data_error->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*  ENDTRY.
*
*  TRY.
*      DATA(lr_aggregations) = cr_salv->get_aggregations( ).
*      lr_aggregations->add_aggregation( EXPORTING columnname  = 'COMPLEXITY' ).                            " ALV Control: Field Name of Internal Table Field
*
*    CATCH cx_salv_data_error INTO DATA(lcx_aggr_cx_salv_data_error).
*      lv_msg = lcx_aggr_cx_salv_data_error->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*    CATCH cx_salv_not_found INTO DATA(lcx_aggr_salv_not_found).
*      lv_msg = lcx_aggr_salv_not_found->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*    CATCH cx_salv_existing INTO DATA(lcx_aggr_salv_existing).
*      lv_msg = lcx_aggr_salv_existing->get_text( ).
*      MESSAGE lv_msg TYPE 'I'.
*  ENDTRY.
*
*  " add custom Excel Email function
*  break speitkar.
*  cr_salv->set_screen_status(
*pfstatus = 'SALV_TABLE_STANDARD'
*report = sy-repid
*set_functions = cr_salv->c_functions_all ).
*
**  cr_salv->get_functions( )->set_all( abap_false ).
*
*  TRY.
*  cr_salv->get_functions( )->add_function(
*    EXPORTING
*      name     = 'XLSX_MAIL'                 " ALV Function
*      icon     = |{ icon_export }|
**      text     =
*      tooltip  = 'Export as XLSX and email'
*      position = if_salv_c_function_position=>right_of_salv_functions                  " Positioning Function
*  ).
*  CATCH cx_salv_existing.   " ALV: General Error Class (Checked During Syntax Check)
*  CATCH cx_salv_wrong_call. " ALV: General Error Class (Checked During Syntax Check)
*  CATCH CX_SALV_METHOD_NOT_SUPPORTED.
*
*  ENDTRY.
*
*  SET HANDLER lcl_events=>on_toolbar_click FOR cr_salv->get_event( ).
*
*  cr_salv->get_functions( )->set_all( if_salv_c_bool_sap=>true ).
*  cr_salv->display( ).

ENDFORM.




*
