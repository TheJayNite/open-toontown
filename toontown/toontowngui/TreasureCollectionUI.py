from direct.gui.DirectGui import *
from direct.showbase.MessengerGlobal import messenger

class TreasureCollectionUI():
    container = None

    def __init__(self):
        self.load()
        messenger.accept('treasureCollectionChanged', base.localAvatar, self.updateInfo)

    def load(self):
        gui = loader.loadModel('phase_3/models/gui/dialog_box_gui')
        # Background + Amount Text
        self.container = DirectFrame(
            relief=None,
            image=gui,
            scale=(0.2, 1.0, 0.2),
            pos=(-1.2, 0.0, -0.62),
            text='0',
            text_pos=(0.0, -0.36),
            text_scale=0.4,
        )
        self.container.hide()
        # Title Text
        OnscreenText(
            parent=self.container,
            text='Treasures\nCollected',
            pos=(0.0, 0.28),
            scale = 0.2,
        )
        gui.removeNode()

    def updateInfo(self):
        self.container['text'] = str(base.localAvatar.getTreasuresCollectedInZone(base.localAvatar.zoneId))
        self.container.show()
        # Task to hide UI after a delay.
        self.stopTask()
        taskMgr.doMethodLater(8.0, lambda _: self.container.hide(), 'hideTreasureCollectUI')

    def stopTask(self):
        taskMgr.remove('hideTreasureCollectUI')

    def unload(self):
        self.stopTask()
        self.container.destroy()
        self.container = None
