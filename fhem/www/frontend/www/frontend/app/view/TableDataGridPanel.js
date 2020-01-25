/**
 * The GridPanel containing a table with rawdata from Database
 */
Ext.define('FHEM.view.TableDataGridPanel', {
    extend: 'Ext.panel.Panel',
    alias : 'widget.tabledatagridpanel',
    requires: [
        'FHEM.store.TableDataStore'
    ],
    
    title: 'Table Data',
    
    layout: 'fit',
    
    height: '100%',
    
    /**
     * 
     */
    initComponent: function() {
        
        var me = this;
        
        if (!FHEM.dblogname) {
            Ext.Msg.alert("Error", "This function is currently only available to users of DbLog!");
        }
        
        me.tablestore = Ext.create('FHEM.store.TableDataStore');

        me.devicestore = Ext.create('FHEM.store.DeviceStore', {
            proxy: {
                type: 'ajax',
                noCache: false,
                method: 'POST',
                url: '../../../fhem?cmd=get+' + FHEM.dblogname + '+-+webchart+""+""+""+getdevices&XHR=1',
                reader: {
                    type: 'json',
                    root: 'data',
                    totalProperty: 'totalCount'
                }
            },
            autoLoad: false
        });
            
        me.devicestore.load();
            
        me.items = [
            {
                xtype: 'fieldset',
                title: 'Configure Database Query',
                maxHeight: 165,
                items: [
                    {
                        xtype: 'fieldset',
                        layout: 'column',
                        defaults: {
                            margin: '5 5 5 10'
                        },
                        items: [
                            {  
                                xtype: 'combobox', 
                                name: 'tddevicecombo',
                                fieldLabel: 'Select Device',
                                labelWidth: 90,
                                store: me.devicestore,
                                allowBlank: false,
                                queryMode: 'local',
                                displayField: 'DEVICE',
                                valueField: 'DEVICE',
                                listeners: {
                                    select: function(combo) {
                                        var device = combo.getValue(),
                                            readingscombo = combo.up().down('combobox[name=tdreadingscombo]'),
                                            readingsstore = readingscombo.getStore(),
                                            readingsproxy = readingsstore.getProxy();
                                        
                                        readingsproxy.url = '../../../fhem?cmd=get+' + FHEM.dblogname + '+-+webchart+""+""+' + device + '+getreadings&XHR=1';
                                        readingsstore.load();
                                        readingscombo.setDisabled(false);
                                    }
                                }
                            },
                            {  
                                xtype: 'combobox', 
                                name: 'tdreadingscombo',
                                fieldLabel: 'Select Reading',
                                allowBlank: false,
                                disabled: true,
                                labelWidth: 90,
                                inputWidth: 110,
                                store: Ext.create('FHEM.store.ReadingsStore', {
                                    proxy: {
                                        type: 'ajax',
                                        method: 'POST',
                                        url: '../../../fhem?cmd=get+' + FHEM.dblogname + '+-+webchart+""+""+-+getreadings&XHR=1',
                                        reader: {
                                            type: 'json',
                                            root: 'data',
                                            totalProperty: 'totalCount'
                                        }
                                    },
                                    autoLoad: false
                                }),
                                displayField: 'READING',
                                valueField: 'READING'
                            }
                        ]
                    },
                    {
                        xtype: 'fieldset',
                        layout: 'column',
                        title: 'Select Timerange',
                        defaults: {
                            margin: '0 0 0 10'
                        },
                        items: [
                            {
                                xtype: 'radiofield',
                                fieldLabel: 'Timerange', 
                                labelWidth: 60,
                                name: 'tdrb', 
                                checked: true,
                                inputValue: 'timerange',
                                listeners: {
                                    change: function(tdrb, newval, oldval) {
                                        if (newval === false) {
                                            tdrb.up().down('datefield[name=tdstarttimepicker]').setDisabled(true);
                                            tdrb.up().down('datefield[name=tdendtimepicker]').setDisabled(true);
                                        } else {
                                            tdrb.up().down('datefield[name=tdstarttimepicker]').setDisabled(false);
                                            tdrb.up().down('datefield[name=tdendtimepicker]').setDisabled(false);
                                        }
                                    }
                                }
                            },
                            {
                              xtype: 'datefield',
                              name: 'tdstarttimepicker',
                              format: 'Y-m-d H:i:s',
                              fieldLabel: 'Starttime',
                              allowBlank: false,
                              labelWidth: 70
                            },
                            {
                              xtype: 'datefield',
                              name: 'tdendtimepicker',
                              format: 'Y-m-d H:i:s',
                              fieldLabel: 'Endtime',
                              allowBlank: false,
                              labelWidth: 70
                            },
                            {
                                xtype: 'radiogroup',
                                name: 'tddynamictime',
                                fieldLabel: 'or select a dynamic time',
                                labelWidth: 140,
                                allowBlank: true,
                                defaults: {
                                    labelWidth: 42,
                                    padding: "0 25px 0 0",
                                    checked: false
                                },
                                items: [
                                    { fieldLabel: 'yearly', name: 'tdrb', inputValue: 'year' },
                                    { fieldLabel: 'monthly', name: 'tdrb', inputValue: 'month' },
                                    { fieldLabel: 'weekly', name: 'tdrb', inputValue: 'week' },
                                    { fieldLabel: 'daily', name: 'tdrb', inputValue: 'day' },
                                    { fieldLabel: 'hourly', name: 'tdrb', inputValue: 'hour' }
                                ]
                            }
                        ]
                    },
                    {
                        xtype: 'button',
                        text: 'Apply Filter',
                        name: 'applytablefilter',
                        width: '120'
                    }
                ]
            },
            {
                xtype: 'gridpanel',
                name: 'tdgridpanel',
                title: 'Data',
                collapsible: true,
                titleCoolapse: true,
                store: me.tablestore,
                loadMask: true,
                columns: [
                      { text: 'TIMESTAMP',  dataIndex: 'TIMESTAMP', width: 240, sortable: false },
                      { text: 'DEVICE', dataIndex: 'DEVICE', width: '10%', sortable: false },
                      { text: 'TYPE',  dataIndex: 'TYPE', width: '7%', sortable: false },
                      { text: 'EVENT',  dataIndex: 'EVENT', width: '20%', sortable: false },
                      { text: 'READING', dataIndex: 'READING', width: '12%', sortable: false },
                      { text: 'VALUE', dataIndex: 'VALUE', width: '20%', sortable: false },
                      { text: 'UNIT', dataIndex: 'UNIT', width: '5%', sortable: false }
                ]
            }
        ];
        me.callParent(arguments);
    }
    
});
