//
//  ViewController.swift
//  RoboControl
//
//  Created by Vincent Spruyt on 17/11/2020.
//

import UIKit
import CoreBluetooth

// The name of our device
let ble_name:String = "Factor";

// UUIDs defined by the BLE standard
let kBLEService_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
let kBLE_Characteristic_uuid_Tx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let kBLE_Characteristic_uuid_Rx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"


let BLEService_UUID = CBUUID(string: kBLEService_UUID)
let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var myPeripheral: CBPeripheral!
    
    var txCharacteristic : CBCharacteristic?
    var rxCharacteristic : CBCharacteristic?
    var characteristicASCIIValue = NSString();
    
    @IBOutlet weak var speedcontrol: UISlider! {
        didSet {
            speedcontrol.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)
        } // didSet
    } // IBOutlet
    
    @IBOutlet weak var steercontrol: UISlider!
    
    @IBOutlet weak var logarea: UITextView!
    
    var prev_speed: Float = 0.0;
    var prev_steer: Float = 0.0;
    var prev_ble_sent_time = CACurrentMediaTime();
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            logarea.text = "Bluetooth powered on. Scanning for Bluetooth ID 'Factor' now...";
            central.scanForPeripherals(withServices: nil, options: nil);
        }
        else {
            logarea.text = "Something wrong with Bluetooth";
        }

    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let pname = peripheral.name {
            if pname == ble_name {
                logarea.text = "'Factor' has been found! Pairing...'";
                self.centralManager.stopScan()
                
                self.myPeripheral = peripheral
                self.myPeripheral.delegate = self
         
                sleep(2);
                self.centralManager.connect(peripheral, options: nil)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        logarea.text = "Discovered services!";
        if ((error) != nil) {
            logarea.text = "Error discovering services: \(error!.localizedDescription)";
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            
            peripheral.discoverCharacteristics(nil, for: service)
            // bleService = service
        }
        logarea.text = "Discovered Services: \(services)";
        print("Discovered Services: \(services)");
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
                       
            if ((error) != nil) {
                print("Error discovering services: \(error!.localizedDescription)")
                return
            }
            
            guard let characteristics = service.characteristics else {
                return
            }
            
            logarea.text = "Found \(characteristics.count) characteristics!"
            print("Found \(characteristics.count) characteristics!")
        
            for characteristic in characteristics {
                //looks for the right characteristic
                
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                   rxCharacteristic = characteristic
                    
                    //Once found, subscribe to the this particular characteristic...
                    peripheral.setNotifyValue(true, for: rxCharacteristic!)
                    // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                    // didUpdateNotificationStateForCharacteristic method will be called automatically
                    peripheral.readValue(for: characteristic)
                    logarea.text = "Rx Characteristic: \(characteristic.uuid)"
                    print("Rx Characteristic: \(characteristic.uuid)")
                }
                if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                    txCharacteristic = characteristic
                    logarea.text = "Tx Characteristic: \(characteristic.uuid)"
                    print("Tx Characteristic: \(characteristic.uuid)")
                }
            peripheral.discoverDescriptors(for: characteristic)
        }
        
        speedcontrol.isUserInteractionEnabled=true;
        steercontrol.isUserInteractionEnabled=true;
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            guard characteristic == rxCharacteristic,
                let characteristicValue = characteristic.value,
                let ASCIIstring = NSString(data: characteristicValue,
                                           encoding: String.Encoding.utf8.rawValue)
                else { return }
            
            characteristicASCIIValue = ASCIIstring
        
        let val = (characteristicASCIIValue as String);
        if let startpos = val.firstIndex(of: "\u{01}"){
            let newval = val.substring(from: startpos);
            logarea.text = newval;
        }
        else{
            logarea.text += val;
        }
//        \001\002
        print("Value Recieved: \((characteristicASCIIValue as String))")
        NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: self)
        }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {

            if (error != nil) {
                print("Error changing notification state:\(String(describing: error?.localizedDescription))")
                
            } else {
                print("Characteristic's value subscribed")
            }
            
            if (characteristic.isNotifying) {
                print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
            }
        }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logarea.text = "Bluetooth has been paired with 'Factor'!";
        
        peripheral.discoverServices([BLEService_UUID])
    }
        
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil);
        
        // Add a gesture recognizer to the slider
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(speedSliderTapped(gestureRecognizer:)))
        speedcontrol.addGestureRecognizer(tapGestureRecognizer)
        
        let steertapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(steerSliderTapped(gestureRecognizer:)))
        steercontrol.addGestureRecognizer(steertapGestureRecognizer)
    }
    
    @objc func speedSliderTapped(gestureRecognizer: UIGestureRecognizer) {
            //  print("A")

            let pointTapped: CGPoint = gestureRecognizer.location(in: self.view)

            let positionOfSlider: CGPoint = speedcontrol.frame.origin
            let widthOfSlider: CGFloat = speedcontrol.frame.size.height
        let newValue = (((pointTapped.y - positionOfSlider.y) / widthOfSlider) * CGFloat(speedcontrol.minimumValue)) + ((1 - ((pointTapped.y - positionOfSlider.y) / widthOfSlider)) * CGFloat(speedcontrol.maximumValue))
        speedcontrol.setValue(Float(newValue), animated: true)
        UpdateSpeed();
        }
    
    @objc func steerSliderTapped(gestureRecognizer: UIGestureRecognizer) {

            let pointTapped: CGPoint = gestureRecognizer.location(in: self.view)

            let positionOfSlider: CGPoint = steercontrol.frame.origin
            let widthOfSlider: CGFloat = steercontrol.frame.size.width
        let newValue = (((pointTapped.x - positionOfSlider.x) / widthOfSlider) * CGFloat(steercontrol.maximumValue)) + ((1 - ((pointTapped.x - positionOfSlider.x) / widthOfSlider)) * CGFloat(steercontrol.minimumValue))
        steercontrol.setValue(Float(newValue), animated: true)
        UpdateSteering();
        }

        
    func UpdateSpeed(){
        var val = speedcontrol.value;
//        let strval = String(format:"%@ is %f", "Speed", val);
//        logarea.text = strval;
        
        var sign_switch = false;
        if((prev_speed<0 && val>=0) || (prev_speed>0 && val<=0)){
            sign_switch = true;
            let generator = UIImpactFeedbackGenerator(style: .heavy);
            generator.impactOccurred();
        }
        
        let newtime = CACurrentMediaTime()
        let timediff = (newtime-prev_ble_sent_time)*1000
        
        // Baud rate is 9600.
        // We are sending 7 bytes per message, so that is 56 bits.
        // We are also receiving about 30 bytes per message, so that is 240 bits.
        // That means we can send 32 messages per second.
        // So we need about 32 milliseconds between each message.
        if(timediff>=32 && (abs(prev_speed-val) >= 0.01 || sign_switch)){
            var bytes:Array<UInt8> = [ 0x01, 0x02, 0, 0, 0, 0, 0 ];
            
            memcpy(&(bytes[3]), &val, 4);
            let Transmitdata = NSData(bytes: bytes, length: bytes.count)
            self.myPeripheral.writeValue(Transmitdata as Data, for: txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            
            prev_ble_sent_time = newtime
            prev_speed = val;
        }
    }
    
    func UpdateSteering(){
        var val = steercontrol.value;
//        let strval = String(format:"%@ is %f", "Steering", val);
//        logarea.text = strval;
        
        var sign_switch = false;
        if((prev_steer<0 && val>=0) || (prev_steer>0 && val<=0)){
            sign_switch = true;
            let generator = UIImpactFeedbackGenerator(style: .heavy);
            generator.impactOccurred();
        }
        
        let newtime = CACurrentMediaTime()
        let timediff = (newtime-prev_ble_sent_time)*1000
        
        // Baud rate is 9600.
        // We are sending 7 bytes per message, so that is 56 bits.
        // We are also receiving about 30 bytes per message, so that is 240 bits.
        // That means we can send 32 messages per second.
        // So we need about 32 milliseconds between each message.
        if(timediff>=32 && (abs(prev_steer-val) >= 0.01 || sign_switch)){
            var bytes:Array<UInt8> = [ 0x01, 0x02, 1, 0, 0, 0, 0 ];
            memcpy(&(bytes[3]), &val, 4);
            let Transmitdata = NSData(bytes: bytes, length: bytes.count)
            self.myPeripheral.writeValue(Transmitdata as Data, for: txCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
            
            prev_ble_sent_time = newtime
            prev_steer = val;
        }
                
    }
    
    @IBAction func SpeedChanged(_ sender: UISlider) {
        UpdateSpeed();
    }
    
    @IBAction func SpeedReleased(_ sender: UISlider) {
        sender.setValue(0.0, animated:true);
        let generator = UIImpactFeedbackGenerator(style: .heavy);
        generator.impactOccurred();
        UpdateSpeed();
    }
    @IBAction func SpeedReleasedOutside(_ sender: UISlider) {
        SpeedReleased(sender);
    }
    @IBAction func SteerChanged(_ sender: UISlider) {
        UpdateSteering();
    }
    @IBAction func SteerReleased(_ sender: UISlider) {
        sender.setValue(0.0, animated:true);
        let generator = UIImpactFeedbackGenerator(style: .heavy);
        generator.impactOccurred();
        UpdateSteering();
    }
    @IBAction func SteerReleasedOutside(_ sender: UISlider) {
        SteerReleased(sender);
    }
}

