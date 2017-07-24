/**
 * Created by lichengke on 2017/7/18.
 */

import config from '../../config'
import {
    NativeModules,
    NativeEventEmitter
} from 'react-native'
import device from '../../modules/device';
import orderServer from '../../services/getIAPOrderIDService'
import account from '../../modules/account';

const IAPManager = NativeModules.IAPManager;
const iAPManagerEmitter = new NativeEventEmitter(IAPManager);
const productIDs = config.productIDs;

let products = null;
let productsListen = null;
let buyResultListen = null;
let matchInfo = null;
let waitForGetProductFormAppleThenRequest = false;

// --->  加载的时候加载商品 点击购买 ----> 查看有没有商品 ---> 有商品请求订单id ---->有商品就购买bugProduct

function listenProducsWithMatchInfo(match,e){

    matchInfo = match;

    productsListen = iAPManagerEmitter.addListener(
        'RNEventReceivedProducts',
        (data) => {
            console.log('RNEventReceivedProducts:',data);
            if(data.products){
                products = data.products;
                if (waitForGetProductFormAppleThenRequest) {
                    waitForGetProductFormAppleThenRequest = false;
                    data.products.length && getOrderIdWithInfo(matchInfo,products[0]);
                }
            }
        }
    );

    buyResultListen = iAPManagerEmitter.addListener(
        'RNEventPurchaseResult',
        (data) => {
            console.log('RNEventPurchaseResult iAPManagerEmitter',data);
            e(data);
        }
    );

    getProducts();
}

function removeListen(){
    productsListen.remove();
    buyResultListen.remove();
}


//一鍵購買
function bugProduct(){
     if (products) {
         if (products.length){
             getOrderIdWithInfo(matchInfo,products[0]);
         }
         else {
             console.log('維護到商品,商品列表為空')
         }
     }
     else {
         waitForGetProductFormAppleThenRequest = true;
     }
}

function consumeProductWithID(userID){
    if (products.length > 0){
        let p = products[0];
        let pID = p.pID;
        // let userId = device.getDeviceId();
        let count = 1;
        IAPManager.chooseProducts(pID,userID,count);
    }
}

function getProducts(){
    if (!products){
        IAPManager.getProductsWithIds(productIDs);
    }
}

function handleMatchData(matchInfo,productID){

    let info = {
        league:matchInfo.ev_type_id,
        round:matchInfo.round,
        matchId:matchInfo.ev_id,   //这里是ev_id
        matchTeams:matchInfo.desc,
        orderType:'1',
        productId:productID,
        account:'',
    }

    return new Promise((resolve, reject) => {
        device.getDeviceId().then((deviceData)=>{
            console.log('deviceData',deviceData);
            info.deviceId = deviceData;
            account.getAccountInfo().then((accountInfo)=>{
                console.log('handleMatchData getAccountInfo:',accountInfo);
                if (accountInfo.isLogined != '0'){
                    info.account = accountInfo.accountNo;
                }
                resolve(info);
            })
        })
    });

}

function getOrderIdWithInfo(data,product){
    handleMatchData(data,product.pID).then(
        (matchData)=>{
            orderServer.getOrderID(matchData).then(
                (reqData)=>{
                    console.log('getOrderID reqData:',reqData);
                    // 得到orderid 然後 consumeProductWithID(orderid)
                    if(reqData.errorCode == 'success' && reqData.data){
                        consumeProductWithID(reqData.data)
                    }
                }
                ,
                (repData)=>{
                    console.log('response error :',repData);
                }
            )
        }
    );
}

export {listenProducsWithMatchInfo,removeListen,bugProduct}


/*
 errorCode
 0     交易已经提交
 1     购买完成,向自己的服务器验证
 2     交易失败
 3     交易恢复购买商品
 4     交易正在处理中

 100    服务器验证成功
 101    服务器验证失败
 */