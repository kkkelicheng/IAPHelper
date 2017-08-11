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
let noProductHandler = null;

// --->  加载的时候加载商品 点击购买 ----> 查看有没有商品 ---> 有商品请求订单id ---->有商品就购买bugProduct

function listenProducsWithMatchInfo(match,e,pe){

    matchInfo = match;

    productsListen = iAPManagerEmitter.addListener(
        'RNEventReceivedProducts',
        (data) => {
            console.log('RNEventReceivedProducts:',data);
            const errorCode = data.errorCode;
            if(errorCode == 0){
                products = data.products;
                console.log('waitForGetProductFormAppleThenRequest status:',waitForGetProductFormAppleThenRequest);
                if (waitForGetProductFormAppleThenRequest) {
                    waitForGetProductFormAppleThenRequest = false;
                        console.log('waitForGetProductFormAppleThenRequest true and buyProductsWithOrder');
                        buyProductsWithOrder(matchInfo.matchId);
                }
            }
            else {
                pe(data);
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

}

function removeListen(){
    productsListen.remove();
    buyResultListen.remove();
    noProductHandler = null;
}

function checkExistOrderInfo(e){
    IAPManager.getUnFinishOrder((orderInfo)=>{
       e(orderInfo);
    })
}

function buyProductsWithOrder(matchId){
    IAPManager.getUnFinishOrder((orderInfo)=>{
        if(orderInfo && orderInfo.orderId != '-1'){
            continuePurchaseWithInfo(products[0],orderInfo.orderId,matchId);
        }
        else {
            getOrderIdWithInfo(matchInfo,products[0],matchId);
        }
    })
}

//一鍵購買
function bugProduct(matchId){
     if (products && products.length > 0) {
         console.log('一键购买 product exist');
            buyProductsWithOrder(matchId);
     }
     else {
         waitForGetProductFormAppleThenRequest = true;
         getProducts();
     }
}

function consumeProductWithID(userID,matchId){
    if (products.length > 0){
        let p = products[0];
        let pID = p.pID;
        // let userId = device.getDeviceId();
        let count = 1;
        IAPManager.chooseProducts(pID,userID,count,matchId);
    }
}

function continuePurchaseWithInfo(product,orderId,matchId){
    let pID = product.pID;
    IAPManager.continuePurchaseProducts(pID,orderId,1,matchId);
}

function getProducts(){
        IAPManager.getProductsWithIds(productIDs);
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

function getOrderIdWithInfo(data,product,matchId){
    handleMatchData(data,product.pID).then(
        (matchData)=>{
            orderServer.getOrderID(matchData).then(
                (reqData)=>{
                    console.log('getOrderID reqData:',reqData);
                    // 得到orderid 然後 consumeProductWithID(orderid)
                    if(reqData.errorCode == 'success' && reqData.data){
                        consumeProductWithID(reqData.data,matchId)
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

function goSystemSetting() {
    IAPManager.goSystemSetting();
}

export {listenProducsWithMatchInfo,removeListen,bugProduct,checkExistOrderInfo,goSystemSetting}


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