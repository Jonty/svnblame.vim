if exists("loadedSvnBlame")
    finish
endif

let loadedSvnBlame = 1

function SvnBlame()
    let thisFile = expand("%")

    " Check that this file is actually in SVN
    let filePath = system('dirname ' . thisFile)
    let filePath = substitute(filePath, "\n", "", "g")
    if !isdirectory(filePath . '/.svn')
        echohl WarningMsg | echon thisFile . " is not in SVN, cannot blame this file."
        return
    endif

    " Check to see if this file has been changed before we opened it
    " of if it has been changed since we opened it
    let fileDiff = system("svn diff " . thisFile)
    if len(fileDiff) > 0 || &modified == 1
        echohl WarningMsg | echon thisFile . " has been changed, cannot blame this file."
        return
    endif

    echo "Blaming '" . thisFile . "'..."

    " Save this window state, bind scroll vertically to children, turn off wrapping
    let parentView = winsaveview()
    set scrollbind
    set scrollopt=ver
    set nowrap

    " Blame baby blame
    let blameSrc = system('svn blame ' . thisFile . ' | sed -r -e "s/( *[0-9]+) +([a-zA-Z0-9]+).*/ \1  \2 /"')
    let blameLines = split(blameSrc, "\n")

    let blameOutput = ""
    let blameWidth = 0
    let i = 0

    while i < len(blameLines)
        let line = blameLines[i]
        let lineLen = strlen(line)
        if lineLen > 0
            let blameOutput .= line . "\n"
            let blameWidth = max([blameWidth, lineLen])
        endif
        let i = i + 1
    endwhile

    " Create a new buffer, dump output and nuke the blank line inserted on creation
    0vnew
    put =blameOutput
    1d
    execute "vertical resize " . blameWidth

    " Make the child a non-wrapping scratch buffer
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber

    " Sync the child to the same vert position in the file as the parent
    let childView = winsaveview()
    let childView.lnum = parentView.lnum
    let childView.topline = parentView.topline
    call winrestview(childView)

    " Locally rebind the trigger to close the child
    nnoremap <buffer> <silent> <C-b> :call EndSvnBlame()<CR>
    " And also close the child if we move to another buffer 
    " (prevents having more than one blame open)
    augroup blame
        autocmd BufLeave * call EndSvnBlame()
    augroup end

    " This gets rid of the dreaded 'Press ENTER or type command to continue'
    " message you get after echoing
    redraw
endf

function EndSvnBlame()
    execute ":close"
    autocmd! blame
endf

map <C-b> :call SvnBlame()<CR>
