function removeFigCaption(fig)    
    jFrame = get(handle(fig),'JavaFrame');
    pause(0.1);
    hWnd = int64(jFrame.fHG1Client.getWindow.getHWnd);
    CaptionlessWindow(hWnd);
end

