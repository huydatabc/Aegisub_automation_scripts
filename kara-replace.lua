script_name="Karaoke replacer"
script_description="Replaces the syllables of a verse"
script_version="0.2.1"

--Fuck it, I should comment this code. Her goes
function kara_replace(sub,sel)
	for si,li in ipairs(sel) do
		--Read in line
		line=sub[li]
		
		--Split at karaoke tags and create table of tags and text
		line_table={}
		
		for tag,text in line.text:gmatch("({[^{}]*\\[kK][^{}]*})([^{}]*)") do
			table.insert(line_table,{["tag"]=tag,["text"]=text})
		end
		
		--Put the line back together with spaces between syllables
		rebuilt_original=""
		
		for i,val in ipairs(line_table) do
			rebuilt_original=rebuilt_original..val.text.." "
		end
		
		--Add some padding so it displays better
		rebuilt_original=rebuilt_original..string.rep(" ",math.floor(rebuilt_original:len()/2))
		
		--Dialog display
		config=
		{
			{
				class="label",
				label=rebuilt_original,
				x=0,y=0,width=1,height=1
			}
			,
			{
				class="edit",
				name="replace",
				x=0,y=1,width=1,height=1
			}
		}
		
		--Instructions
		help_config=
		{
			{
				class="label",
				label=
				"The syllables of the original line will be displayed.\n"..
				"Type the syllables you would like to replace them with,\n"..
				"with spaces between each syllable.\n\n"..
				"If you want a space in the lyrics, type a double space.\n"..
				"Two join a syllable with the one after it, put a + after\n"..
				"the syllable.\n"..
				"To split a syllable (you'll have to adjust it yourself),\n"..
				"put a | where you want the split.\n"..
				"To insert a blank syllable (for padding), type _\n"..
				"You can ignore any blank syllables in the original line.\n\n"..
				"Example:\n"..
				"_ ko re  wa+  re|i  de su",
				x=0,y=0,width=1,height=1
			}
		}
		
		--Show dialog and get input for each line
		pressed=nil
		
		repeat
			pressed,result=aegisub.dialog.display(config,{"Next line","Help"})
			if pressed=="Help" then
				aegisub.dialog.display(help_config,{"OK"})
			end
		until pressed~="Help"
		
		--Split input at spaces and store in table
		replace={}
		
		for newsyl in result["replace"]:gsub("  ","\t "):gmatch("[^ ]+") do
			newsyl=newsyl:gsub("\t"," ")
			table.insert(replace,newsyl)
		end
		
		rebuilt_text=""
		
		--Indices of original and replacement tables
		oi=1
		ri=1
		
		while oi<=#line_table do
			--Skip if it's a blank syl (used for padding) or we're out of replacements
			if line_table[oi].text:len()>0 and replace[ri]~=nil then
				--Handle splitting syls
				if replace[ri]:find("|")~=nil then
					
					--Split the replacement line at | characters
					subtab={}
					for subsyl in replace[ri]:gmatch("[^|]+") do
						table.insert(subtab,subsyl)
					end
					
					--Find the original time of the karaoke syllable
					otime=tonumber(line_table[oi].tag:match("\\[kK][fo]?(%d+)"))
					--The remaining time (for last syl, to ensure they add up to the original time)
					ltime=otime
					--Add all but the last syl
					for x=1,#subtab-1,1 do
						--To minimize truncation error, alternate between ceil and floor
						ttime=0
						if x%2==1 then
							ttime=math.floor(otime/#subtab)
						else
							ttime=math.ceil(otime/#subtab)
						end
						rebuilt_text=rebuilt_text..
							line_table[oi].tag:gsub("(\\[kK][fo]?)%d+","\1"..tostring(ttime))..
							subtab[x]
						ltime=ltime-ttime
					end
					--Add the last syl
					rebuilt_text=rebuilt_text..
						line_table[oi].tag:gsub("(\\[kK][fo]?)%d+","\1"..tostring(ltime))..
						subtab[#subtab]
				
				--Handle merging syls
				--Only merge if it's not the last syl
				elseif replace[ri]:find("+")~=nil and oi<#line_table then
					temp_tag=line_table[oi].tag
					oi=oi+1
					stime=tonumber(line_table[oi].tag:match("\\[kK][fo]?(%d+)"))
					temp_tag=temp_tag:gsub("(\\[kK][fo]?)(%d+)",function(a,b)
							return a..tostring(tonumber(b)+stime)
						end)
					rebuilt_text=rebuilt_text..temp_tag..replace[ri]:gsub("+","")
					
				--The usual replacement
				else
					rebuilt_text=rebuilt_text..line_table[oi].tag..replace[ri]:gsub("_","")
				end
				
				--Increment indices
				oi=oi+1
				ri=ri+1
			else
				rebuilt_text=rebuilt_text..line_table[oi].tag
				oi=oi+1
			end
		end
		
		line.text=rebuilt_text
		sub[li]=line
		if finished then break end
	end
end

--Old behavior. If automations are ever modified so that hitting "enter" from a text box
--will execute the "OK" button, then this behavior is probably better.
--For now, this function doesn't do anything
function kara_replace_old(sub,sel)
	for si,li in ipairs(sel) do
		line=sub[li]
		
		line_table={}
		
		for tag,text in line.text:gmatch("({[^{}]*\\[kK][^{}]*})([^{}]*)") do
			table.insert(line_table,{["tag"]=tag,["text"]=text})
		end
		
		rebuilt_text=""
		
		finished=false
		
		for i,val in ipairs(line_table) do
			
			local function hl_syl(lt,idx)
				result=""
				for k,a in ipairs(lt) do
					if k==idx then result=result.." ["..a.text:upper().."] "
					else result=result..a.text end
				end
				return result
			end
			
			if val.text:len()<1 or finished then
				rebuilt_text=rebuilt_text..val.tag..val.text
			else
				config=
				{
					{
						class="label",
						label="Enter the syllable to replace with, or nothing to close.",
						x=0,y=0,width=1,height=1
					},
					{
						class="label",
						label=hl_syl(line_table,i),
						x=0,y=2,width=1,height=1
					},
					{
						class="edit",
						name="replace",
						x=0,y=3,width=1,height=1
					}
				}
				_,res=aegisub.dialog.display(config,{"OK"})
				if res["replace"]:len()<1 then
					rebuilt_text=rebuilt_text..val.tag..val.text
					finished=true
				else
					rebuilt_text=rebuilt_text..val.tag..res["replace"]
				end
			end
		end
		line.text=rebuilt_text
		sub[li]=line
		if finished then break end
	end
end

aegisub.register_macro(script_name,script_description,kara_replace)