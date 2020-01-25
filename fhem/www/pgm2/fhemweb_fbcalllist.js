FW_version["fhemweb_fbcalllist.js"] = "$Id: fhemweb_fbcalllist.js 21006 2020-01-18 08:16:23Z markusbloch $";

// WORKAROUND - should be removed if a more suitable solution is found
// remove all similar informid's in all parent elements to ensure further updates.
//
// neccessary if general attribute "group" is set.
$(function () {
    $("div[arg=fbcalllist][informid]").each(function (index, obj) {
        name = $(obj).attr("dev");
        $(obj).parents('[informid="'+name+'"]').removeAttr("informid");
    });
});

function FW_processCallListUpdate(data)
{
    var table = $(this).find("table.fbcalllist").first();
    var json_data = jQuery.parseJSON(data)

    // clear the list
    if(json_data.action == "clear")
    {
        // if the table isn't already empty
        if(!table.find("tr[name=empty]").length)
        {
            table.find("tr[number]").remove();
            table.append("<tr align=\"center\" name=\"empty\"><td style=\"padding:10px;\" colspan=\""+table.find("tr.header td").length+"\">"+json_data.content+"</td></tr>");
        }
        return;
    }

    // remove deleted item
    if(json_data.action == "delete")
    {
        table.find("tr[index='"+json_data.index+"']").remove();
        FW_FbCalllistUpdateRowNumbers(table);
        return;
    }

    // hide the complete table
    if(json_data.action == "hide")
    {
        table.hide();
        return;
    }

    // show the complete table
    if(json_data.action == "show")
    {
        table.show();
        return;
    }

    // update a item with new data
    if(json_data.action == "update")
    {
        if(table.find("tr[index='"+json_data.index+"']").length)
        {
             $.each(json_data.item, function (key, val) {

                if(key == "line")
                { return true; }

                FW_setCallListValue(table,json_data.index,key,val);
             });
        }
        else // add new tr row with the values)
        {
            // delete the empty tr row if it may exist
            table.find("tr[name=empty]").remove();

            var new_tr = '<tr align="center" number="'+json_data.item.line+'" index="'+json_data.index+'" class="fbcalllist item '+((json_data.item.line % 2) == 1 ? "odd" : "even")+'">';
            var style = "style=\"padding-left:6px;padding-right:6px;\"";

             // create the corresponding <td> tags with the received data
            $.each(json_data.item, function (key, val) {
                if(key == "line")
                { return true; }
                else if(key == "image")
                {
                    new_tr += '<td name="'+key+'" '+style+'><img style="max-height:3em;" src="'+val+'"></td>';
                }
                else
                {
                    new_tr += '<td name="'+key+'" '+style+'>'+val+'</td>';
                }
             });

            new_tr += "</tr>";

            // insert new tr into table
            if(json_data.order == "ascending")
            {
                table.append(new_tr);
            }
            else
            {
                table.find("tr.header").after(new_tr);
            }
            FW_FbCalllistUpdateRowNumbers(table);
        }
        return;
    }
}

function FW_FbCalllistUpdateRowNumbers(table)
{
    count = 0;
    table.find("tr.item").each(function(index, obj) {

        var oldClass = ((parseInt($(obj).attr("number")) % 2) == 1 ? "odd" : "even");

        $(obj).attr("number", ++count);

        var newClass = ((count % 2) == 1 ? "odd" : "even");

        $(obj).removeClass(oldClass);
        $(obj).addClass(newClass);
        $(obj).find("td[name='row']").html(count);
    });
}

function FW_setCallListValue(table,index,key,val)
{
    var el = table.find("tr[index='"+index+"'] td[name="+key+"]");
    
    if(key == "image")
    {
        el.children("img").attr("src", val);
    }
    else
    {
        el.html(val);
    }
}

function FW_FbCalllistCreate(elName, devName, vArr, currVal, set, params, cmd)
{
    if(vArr[0] == "fbcalllist")
    {
        var newEl = $('div[informid="'+devName+'"]').get(0);

        newEl.setValueFn = FW_processCallListUpdate;

        return newEl;
    }
}

FW_widgets['fbcalllist'] = {
  createFn:FW_FbCalllistCreate
};
